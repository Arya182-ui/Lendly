import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';import 'package:lendly/widgets/app_image.dart';import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'chat_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MessagesScreen extends StatefulWidget {
	const MessagesScreen({super.key});

	@override
	State<MessagesScreen> createState() => _MessagesScreenState();
}

// Robust avatar widget for both asset and network images
class RobustAvatar extends StatelessWidget {
	final String? url;
	final double radius;
	const RobustAvatar({Key? key, this.url, this.radius = 26}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		if (url == null || url!.isEmpty) {
			return CircleAvatar(
				radius: radius,
				child: Icon(Icons.person, color: Colors.green[700]),
			);
		}
		// If the url looks like a local asset path
		if (!url!.startsWith('http')) {
			if (url!.endsWith('.svg')) {
				return CircleAvatar(
					radius: radius,
					backgroundColor: Colors.grey[200],
					child: ClipOval(
						child: SvgPicture.asset(
							url!,
							width: radius * 2,
							height: radius * 2,
							fit: BoxFit.cover,
							placeholderBuilder: (context) => Icon(Icons.person, color: Colors.green[700]),
						),
					),
				);
			} else {
				return CircleAvatar(
					radius: radius,
					backgroundColor: Colors.grey[200],
					child: ClipOval(
						child: Image.asset(
							url!,
							width: radius * 2,
							height: radius * 2,
							fit: BoxFit.cover,
							errorBuilder: (context, error, stackTrace) {
								return Icon(Icons.person, color: Colors.green[700]);
							},
						),
					),
				);
			}
		}
		// Otherwise, treat as network image
		return CircleAvatar(
			radius: radius,
			backgroundColor: Colors.grey[200],
			child: UserAvatar(
				avatarUrl: url!,
				radius: radius,
			),
		);
	}
}

class _MessagesScreenState extends State<MessagesScreen> {
	late String currentUid;

	List<Map<String, dynamic>> myGroups = [];
	Map<String, Map<String, dynamic>> conversationsMap = {};
	bool isLoading = true;
	bool isLoadingGroups = true;
	bool isLoadingChats = true;

	@override
	       void initState() {
		       super.initState();
		       WidgetsBinding.instance.addPostFrameCallback((_) {
			       final userProvider = Provider.of<UserProvider>(context, listen: false);
			       currentUid = userProvider.uid ?? '';
			       _loadData();
							 ChatSocketService().onReceiveMessage((data) {
											 final String peerUid = data['from'] == currentUid ? data['to'] : data['from'];
											 final List<String> roomIdList = [currentUid, peerUid]..sort();
											 final String roomKey = roomIdList.join('_');
											 // Try to find friend info from loaded friends
											 Map<String, dynamic>? friendInfo;
											 for (final f in conversationsMap.values) {
												 if (f['peerUid'] == peerUid) {
													 friendInfo = f;
													 break;
												 }
											 }
											 setState(() {
												 conversationsMap[roomKey] = {
													 'avatar': friendInfo != null ? friendInfo['avatar'] : 'https://randomuser.me/api/portraits/men/32.jpg',
													 'name': friendInfo != null ? friendInfo['name'] : peerUid,
													 'context': 'Direct Chat',
													 'lastMessage': data['message'],
													 'unread': data['from'] != currentUid,
													 'urgent': false,
													 'timestamp': 'now',
													 'peerUid': peerUid,
												 };
											 });
											 // Also save to backend via API (fallback if socket fails)
											 _saveMessageToBackend(roomKey, data['from'], data['message']);
							 });
		       });
	       }

		       Future<void> _loadData() async {
	       setState(() { 
	         isLoading = true; 
	         isLoadingGroups = true;
	         isLoadingChats = true;
	       });
	       try {
		       if (currentUid.isEmpty) {
		       setState(() { 
		         isLoading = false;
		         isLoadingGroups = false;
		         isLoadingChats = false;
		       });
		       return;
	       }
	       
	       // Load groups
	       final groups = await fetchGroups(currentUid);
	       setState(() {
	         myGroups = groups;
	         isLoadingGroups = false;
	       });
	       
	       // Load friends/chats
	       final friends = await fetchFriends(currentUid);
	       
	       setState(() {
		       conversationsMap.clear(); // Clear existing data
		       // Add friends as conversations
		       for (final friend in friends) {
			       final List<String> roomIdList = [currentUid, friend['uid']]..sort();
			       final String roomKey = roomIdList.join('_');
			       conversationsMap[roomKey] = {
				       'avatar': friend['avatar'],
				       'name': friend['name'],
				       'context': 'Direct Chat',
				       'lastMessage': '',
				       'unread': false,
				       'urgent': false,
				       'timestamp': '',
				       'peerUid': friend['uid'],
			       };
		       }
		       isLoadingChats = false;
		       isLoading = false;
	       });
       } catch (e) {
	       setState(() { 
	         isLoading = false;
	         isLoadingGroups = false;
	         isLoadingChats = false;
	       });
	       // Show error message to user
	       if (mounted) {
	         ScaffoldMessenger.of(context).showSnackBar(
	           SnackBar(
	             content: Text('Failed to load chats: ${e.toString().replaceAll('Exception: ', '')}'),
	             backgroundColor: Colors.red,
	             action: SnackBarAction(
	               label: 'Retry',
	               textColor: Colors.white,
	               onPressed: _loadData,
	             ),
	           ),
	         );
	       }
       }
       }

	String search = '';

	@override
	Widget build(BuildContext context) {
		final filteredGroups = myGroups.where((c) =>
			search.isEmpty ||
			c['name'].toLowerCase().contains(search.toLowerCase()) ||
			c['context'].toLowerCase().contains(search.toLowerCase())
		).toList();
		final filteredChats = conversationsMap.values.where((c) =>
			search.isEmpty ||
			c['name'].toLowerCase().contains(search.toLowerCase()) ||
			c['context'].toLowerCase().contains(search.toLowerCase())
		).toList();

		return Scaffold(
			backgroundColor: const Color(0xFFF8FAFB),
			appBar: AppBar(
				backgroundColor: Colors.white,
				elevation: 0.5,
				leading: Navigator.canPop(context)
						? IconButton(
								icon: const Icon(Icons.arrow_back, color: Color(0xFF1a237e)),
								onPressed: () => Navigator.of(context).pop(),
							)
						: null,
				title: const Text('Chats', style: TextStyle(color: Color(0xFF1a237e), fontWeight: FontWeight.bold)),
				centerTitle: true,
			),
			body: Column(
				children: [
					// Search bar
					Padding(
						padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
						child: Container(
							decoration: BoxDecoration(
								color: Colors.white,
								borderRadius: BorderRadius.circular(14),
								boxShadow: [
									BoxShadow(
										color: Colors.grey.withOpacity(0.08),
										blurRadius: 8,
										offset: const Offset(0, 2),
									),
								],
							),
							child: TextField(
								onChanged: (val) => setState(() => search = val),
								decoration: const InputDecoration(
									hintText: 'Search chats',
									border: InputBorder.none,
									prefixIcon: Icon(Icons.search, color: Color(0xFF1a237e)),
									contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
								),
								style: const TextStyle(fontSize: 15),
							),
						),
					),
					       Expanded(
						       child: isLoading
							       ? const Center(
							           child: Column(
							             mainAxisAlignment: MainAxisAlignment.center,
							             children: [
							               CircularProgressIndicator(
							                 valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1DBF73)),
							               ),
							               SizedBox(height: 16),
							               Text(
							                 'Loading chats...',
							                 style: TextStyle(
							                   color: Color(0xFF1a237e),
							                   fontSize: 16,
							                   fontWeight: FontWeight.w500,
							                 ),
							               ),
							             ],
							           ),
							         )
							       : (filteredGroups.isEmpty && filteredChats.isEmpty)
								       ? Center(
									       child: Column(
										       mainAxisAlignment: MainAxisAlignment.center,
										       children: [
											       Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
											       const SizedBox(height: 16),
											       Text('No friends or groups yet!', style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w600)),
											       const SizedBox(height: 8),
											       Text('Start by connecting with friends or joining a group.', style: TextStyle(fontSize: 15, color: Colors.grey[500])),
										       ],
									       ),
								       )
								       : ListView.separated(
								padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
								itemCount: filteredGroups.length + filteredChats.length + (isLoadingGroups || isLoadingChats ? 1 : 0),
								separatorBuilder: (_, __) => const SizedBox(height: 2),
								itemBuilder: (context, idx) {
								  if (isLoadingGroups && idx == 0) {
								    return const Card(
								      elevation: 0,
								      color: Colors.white,
								      child: ListTile(
								        leading: CircularProgressIndicator(
								          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1DBF73)),
								        ),
								        title: Text(
								          'Loading groups...',
								          style: TextStyle(
								            color: Color(0xFF1a237e),
								            fontWeight: FontWeight.w500,
								          ),
								        ),
								      ),
								    );
								  }
								  if (isLoadingChats && idx == (isLoadingGroups ? 1 : 0)) {
								    return const Card(
								      elevation: 0,
								      color: Colors.white,
								      child: ListTile(
								        leading: CircularProgressIndicator(
								          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1DBF73)),
								        ),
								        title: Text(
								          'Loading chats...',
								          style: TextStyle(
								            color: Color(0xFF1a237e),
								            fontWeight: FontWeight.w500,
								          ),
								        ),
								      ),
								    );
								  }
								  
								  final adjustedIdx = idx - (isLoadingGroups ? 1 : 0) - (isLoadingChats ? 1 : 0);
									if (adjustedIdx < filteredGroups.length) {
										final c = filteredGroups[adjustedIdx];
										return Card(
											elevation: 0,
											color: Colors.white,
											shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
											child: ListTile(
												leading: Stack(
													children: [
														RobustAvatar(url: c['avatar'], radius: 26),
														if (c['unread'] ?? false)
															Positioned(
																right: 0,
																bottom: 0,
																child: Container(
																	width: 12,
																	height: 12,
																	decoration: BoxDecoration(
																		color: c['urgent'] ? Colors.red : const Color(0xFF1DBF73),
																		shape: BoxShape.circle,
																		border: Border.all(color: Colors.white, width: 2),
																	),
																),
															),
													],
												),
												title: Row(
													children: [
														Expanded(
															child: Text(
																c['name'] ?? '',
																style: TextStyle(
																	fontWeight: (c['unread'] ?? false) ? FontWeight.bold : FontWeight.w600,
																	fontSize: 16,
																	color: const Color(0xFF1a237e),
																),
															),
														),
														Text(
															c['timestamp'] ?? '',
															style: const TextStyle(fontSize: 12, color: Colors.black45),
														),
													],
												),
												subtitle: Column(
													crossAxisAlignment: CrossAxisAlignment.start,
													children: [
														Container(
															margin: const EdgeInsets.only(top: 2, bottom: 2),
															padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
															decoration: BoxDecoration(
																color: const Color(0xFFE8F9F1),
																borderRadius: BorderRadius.circular(8),
															),
															child: Text(
																c['context'] ?? '',
																style: const TextStyle(fontSize: 12, color: Color(0xFF1DBF73), fontWeight: FontWeight.w600),
															),
														),
														Text(
															c['lastMessage'] ?? '',
															maxLines: 1,
															overflow: TextOverflow.ellipsis,
															style: TextStyle(
																fontSize: 14,
																color: (c['unread'] ?? false) ? Colors.black : Colors.black54,
																fontWeight: (c['unread'] ?? false) ? FontWeight.bold : FontWeight.normal,
															),
														),
													],
												),
												onTap: () {
													Navigator.push(
														context,
														MaterialPageRoute(
															builder: (_) => ChatScreen(
																name: c['name'] ?? '',
																contextLabel: 'Group',
																avatarUrl: c['avatar'] ?? '',
																isGroup: true,
																trust: true, // You can set this based on your data
																currentUid: currentUid,
																  peerUid: c['id'] ?? c['groupId'] ?? c['peerUid'] ?? '', // Use id/groupId for group chats
															),
														),
													);
												},
											),
										);
									} else {
										final c = filteredChats[adjustedIdx - filteredGroups.length];
										return Card(
											elevation: 0,
											color: Colors.white,
											shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
											child: ListTile(
												leading: RobustAvatar(url: c['avatar'], radius: 26),
												title: Row(
													children: [
														Expanded(
															child: Text(
																c['name'],
																style: TextStyle(
																	fontWeight: c['unread'] ? FontWeight.bold : FontWeight.w600,
																	fontSize: 16,
																	color: const Color(0xFF1a237e),
																),
															),
														),
														Text(
															c['timestamp'],
															style: const TextStyle(fontSize: 12, color: Colors.black45),
														),
													],
												),
												subtitle: Column(
													crossAxisAlignment: CrossAxisAlignment.start,
													children: [
														Container(
															margin: const EdgeInsets.only(top: 2, bottom: 2),
															padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
															decoration: BoxDecoration(
																color: const Color(0xFFE8F9F1),
																borderRadius: BorderRadius.circular(8),
															),
															child: Text(
																c['context'],
																style: const TextStyle(fontSize: 12, color: Color(0xFF1DBF73), fontWeight: FontWeight.w600),
															),
														),
														Text(
															c['lastMessage'],
															maxLines: 1,
															overflow: TextOverflow.ellipsis,
															style: TextStyle(
																fontSize: 14,
																color: c['unread'] ? Colors.black : Colors.black54,
																fontWeight: c['unread'] ? FontWeight.bold : FontWeight.normal,
															),
														),
													],
												),
												onTap: () {
													setState(() {
														c['unread'] = false;
													});
													Navigator.push(
														context,
														MaterialPageRoute(
															builder: (_) => ChatScreen(
																name: c['name'],
																contextLabel: c['context'],
																avatarUrl: c['avatar'],
																isGroup: false,
																trust: true,
																currentUid: currentUid,
																peerUid: c['peerUid'],
															),
														),
													);
												},
											),
										);
									}
								},
							),
					),
				],
			),
		);
	}

	Future<List<Map<String, dynamic>>> fetchFriends(String uid) async {
		final response = await http.get(Uri.parse('https://ary-lendly-production.up.railway.app/user/friends?uid=$uid'));
		if (response.statusCode == 200) {
			final data = jsonDecode(response.body);
			return List<Map<String, dynamic>>.from(data['friends'] ?? []);
		} else {
			throw Exception('Failed to fetch friends');
		}
	}

	Future<List<Map<String, dynamic>>> fetchGroups(String uid) async {
		final response = await http.get(Uri.parse('https://ary-lendly-production.up.railway.app/groups/my?uid=$uid'));
		if (response.statusCode == 200) {
			final List data = jsonDecode(response.body);
			return data.cast<Map<String, dynamic>>();
		} else {
			throw Exception('Failed to fetch groups');
		}
	}

	Future<List<Map<String, dynamic>>> fetchLatestChats(String uid) async {
		final response = await http.get(Uri.parse('https://ary-lendly-production.up.railway.app/chat/list/$uid'));
		if (response.statusCode == 200) {
			final List data = jsonDecode(response.body);
			return data.cast<Map<String, dynamic>>();
		} else {
			throw Exception('Failed to fetch chats');
		}
	}

	String _formatTimestamp(dynamic timestamp) {
		if (timestamp == null) return '';
		try {
			DateTime dt;
			if (timestamp is Map && timestamp.containsKey('_seconds')) {
				dt = DateTime.fromMillisecondsSinceEpoch(timestamp['_seconds'] * 1000);
			} else if (timestamp is String) {
				dt = DateTime.parse(timestamp);
			} else {
				return '';
			}
			final now = DateTime.now();
			final diff = now.difference(dt);
			if (diff.inDays > 0) {
				return '${diff.inDays}d ago';
			} else if (diff.inHours > 0) {
				return '${diff.inHours}h ago';
			} else if (diff.inMinutes > 0) {
				return '${diff.inMinutes}m ago';
			} else {
				return 'now';
			}
		} catch (e) {
			return '';
		}
	}

	Future<void> _saveMessageToBackend(String chatId, String senderId, String message) async {
		try {
			await http.post(
				Uri.parse('https://ary-lendly-production.up.railway.app/chat/send'),
				headers: {'Content-Type': 'application/json'},
				body: jsonEncode({
					'chatId': chatId,
					'senderId': senderId,
					'text': message,
				}),
			);
		} catch (e) {
			print('Failed to save message to backend: $e');
		}
	}
}

// Add a socket connection for real-time updates (for demo, not persistent)
class ChatSocketService {
  static final ChatSocketService _instance = ChatSocketService._internal();
  factory ChatSocketService() => _instance;
  late IO.Socket socket;
  bool _connected = false;

  ChatSocketService._internal() {
	socket = IO.io('https://ary-lendly-production.up.railway.app', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
  }

  void connect() {
    if (!_connected) {
      socket.connect();
      _connected = true;
    }
  }

  void joinRoom(String roomId) {
    connect();
    socket.emit('joinRoom', roomId);
  }

  void sendMessage(Map<String, dynamic> msg) {
    connect();
    socket.emit('sendMessage', msg);
  }

  void onReceiveMessage(Function(dynamic) handler) {
    connect();
    socket.on('receiveMessage', handler);
  }
}
