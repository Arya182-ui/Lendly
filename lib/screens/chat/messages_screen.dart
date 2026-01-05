import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import 'package:lendly/widgets/app_image.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'chat_screen.dart';
import 'dart:convert';
import '../../services/api_client.dart';

import '../../config/env_config.dart';

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
			backgroundColor: const Color(0xFFF8FAFC),
			appBar: AppBar(
				backgroundColor: Colors.white,
				elevation: 0,
				scrolledUnderElevation: 0.5,
				leading: Navigator.canPop(context)
						? IconButton(
								icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 20),
								onPressed: () => Navigator.of(context).pop(),
							)
						: null,
				title: const Text(
					'Messages',
					style: TextStyle(
						color: Color(0xFF1E293B),
						fontWeight: FontWeight.w700,
						fontSize: 20,
						letterSpacing: -0.3,
					),
				),
				centerTitle: true,
				actions: [
					IconButton(
						icon: Container(
							padding: const EdgeInsets.all(8),
							decoration: BoxDecoration(
								color: const Color(0xFF1DBF73).withValues(alpha: 0.1),
								shape: BoxShape.circle,
							),
							child: const Icon(Icons.edit_rounded, color: Color(0xFF1DBF73), size: 18),
						),
						onPressed: () {
							// New chat functionality
						},
					),
					const SizedBox(width: 8),
				],
			),
			body: Column(
				children: [
					// Search bar
					Padding(
						padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
						child: Container(
							decoration: BoxDecoration(
								color: Colors.white,
								borderRadius: BorderRadius.circular(16),
								border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
								boxShadow: [
									BoxShadow(
										color: Colors.black.withValues(alpha: 0.04),
										blurRadius: 10,
										offset: const Offset(0, 4),
									),
								],
							),
							child: TextField(
								onChanged: (val) => setState(() => search = val),
								decoration: InputDecoration(
									hintText: 'Search conversations...',
									hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
									border: InputBorder.none,
									prefixIcon: Padding(
										padding: const EdgeInsets.all(12),
										child: Container(
											padding: const EdgeInsets.all(8),
											decoration: BoxDecoration(
												color: const Color(0xFF1DBF73).withValues(alpha: 0.1),
												borderRadius: BorderRadius.circular(10),
											),
											child: const Icon(Icons.search_rounded, color: Color(0xFF1DBF73), size: 18),
										),
									),
									contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
								),
								style: const TextStyle(fontSize: 15, color: Color(0xFF1E293B)),
							),
						),
					),
					       Expanded(
						       child: isLoading
							       ? Center(
							           child: Column(
							             mainAxisAlignment: MainAxisAlignment.center,
							             children: [
							               Container(
							                 padding: const EdgeInsets.all(20),
							                 decoration: BoxDecoration(
							                   color: const Color(0xFF1DBF73).withValues(alpha: 0.1),
							                   shape: BoxShape.circle,
							                 ),
							                 child: const CircularProgressIndicator(
							                   valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1DBF73)),
							                   strokeWidth: 3,
							                 ),
							               ),
							               const SizedBox(height: 20),
							               const Text(
							                 'Loading conversations...',
							                 style: TextStyle(
							                   color: Color(0xFF64748B),
							                   fontSize: 15,
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
											       Container(
											         padding: const EdgeInsets.all(24),
											         decoration: BoxDecoration(
											           color: const Color(0xFFEC4899).withValues(alpha: 0.1),
											           shape: BoxShape.circle,
											         ),
											         child: const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Color(0xFFEC4899)),
											       ),
											       const SizedBox(height: 24),
											       const Text(
											         'No conversations yet',
											         style: TextStyle(
											           fontSize: 20,
											           color: Color(0xFF1E293B),
											           fontWeight: FontWeight.w700,
											         ),
											       ),
											       const SizedBox(height: 8),
											       Text(
											         'Start by connecting with friends\\nor joining a group',
											         style: TextStyle(fontSize: 14, color: Colors.grey[500], height: 1.5),
											         textAlign: TextAlign.center,
											       ),
											       const SizedBox(height: 24),
											       ElevatedButton.icon(
											         onPressed: () {
											           // Navigate to friends or groups
											         },
											         icon: const Icon(Icons.person_add_rounded, size: 18),
											         label: const Text('Find Friends'),
											         style: ElevatedButton.styleFrom(
											           backgroundColor: const Color(0xFF1DBF73),
											           foregroundColor: Colors.white,
											           elevation: 0,
											           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
											           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
											         ),
											       ),
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
														// Group icon badge
														Positioned(
															right: 0,
															top: 0,
															child: Container(
																padding: const EdgeInsets.all(3),
																decoration: BoxDecoration(
																	color: const Color(0xFF7C3AED),
																	shape: BoxShape.circle,
																	border: Border.all(color: Colors.white, width: 2),
																),
																child: const Icon(
																	Icons.group,
																	size: 12,
																	color: Colors.white,
																),
															),
														),
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
														const Icon(
															Icons.group_rounded,
															size: 16,
															color: Color(0xFF7C3AED),
														),
														const SizedBox(width: 6),
														Expanded(
															child: Text(
																c['name'] ?? '',
																style: TextStyle(
																	fontWeight: (c['unread'] ?? false) ? FontWeight.bold : FontWeight.w600,
																	fontSize: 16,
																	color: const Color(0xFF7C3AED),
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
																color: const Color(0xFFF3E8FF),
																borderRadius: BorderRadius.circular(8),
															),
															child: Row(
																mainAxisSize: MainAxisSize.min,
																children: [
																	const Icon(Icons.groups_rounded, size: 10, color: Color(0xFF7C3AED)),
																	const SizedBox(width: 4),
																	Text(
																		'Group Chat',
																		style: const TextStyle(fontSize: 11, color: Color(0xFF7C3AED), fontWeight: FontWeight.w700),
																	),
																],
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
															builder: (_) => EnhancedChatScreen(
																chatId: c['id'] ?? '',
																peerUid: c['id'] ?? c['groupId'] ?? c['peerUid'] ?? '',
																peerName: c['name'] ?? '',
																peerAvatar: c['avatar'] ?? '',
																isGroup: true,
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
												leading: Stack(
													children: [
														RobustAvatar(url: c['avatar'], radius: 26),
														// Personal chat indicator
														Positioned(
															right: 0,
															top: 0,
															child: Container(
																padding: const EdgeInsets.all(3),
																decoration: BoxDecoration(
																	color: const Color(0xFF1DBF73),
																	shape: BoxShape.circle,
																	border: Border.all(color: Colors.white, width: 2),
																),
																child: const Icon(
																	Icons.person,
																	size: 12,
																	color: Colors.white,
																),
															),
														),
													],
												),
												title: Row(
													children: [
														const Icon(
															Icons.person_outline_rounded,
															size: 16,
															color: Color(0xFF1DBF73),
														),
														const SizedBox(width: 6),
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
															child: Row(
																mainAxisSize: MainAxisSize.min,
																children: [
																	const Icon(Icons.chat_bubble_outline_rounded, size: 10, color: Color(0xFF1DBF73)),
																	const SizedBox(width: 4),
																	Text(
																		'Direct Chat',
																		style: const TextStyle(fontSize: 11, color: Color(0xFF1DBF73), fontWeight: FontWeight.w700),
																	),
																],
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
															builder: (_) => EnhancedChatScreen(
																chatId: c['chatId'] ?? '',
																peerUid: c['uid'] ?? '',
																peerName: c['name'] ?? '',
																peerAvatar: c['avatar'] ?? '',
																isGroup: false,
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
		final data = await SimpleApiClient.get(
			'/user/friends',
			queryParams: {'uid': uid},
			requiresAuth: true,
		);
		if (data is List) {
			return data.cast<Map<String, dynamic>>();
		}
		final list = data['friends'] ?? data;
		if (list is List) return list.cast<Map<String, dynamic>>();
		throw Exception('Failed to fetch friends');
	}

	Future<List<Map<String, dynamic>>> fetchGroups(String uid) async {
		final data = await SimpleApiClient.get(
			'/groups/my',
			queryParams: {'uid': uid},
			requiresAuth: true,
		);
		if (data is List) return data.cast<Map<String, dynamic>>();
		final list = data['groups'] ?? data;
		if (list is List) return list.cast<Map<String, dynamic>>();
		throw Exception('Failed to fetch groups');
	}

	Future<List<Map<String, dynamic>>> fetchLatestChats(String uid) async {
		final data = await SimpleApiClient.get(
			'/chat/list/$uid',
			requiresAuth: true,
		);
		final list = (data is Map) ? data['chats'] : data;
		if (list is List) return list.cast<Map<String, dynamic>>();
		throw Exception('Failed to fetch chats');
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
			await SimpleApiClient.post(
				'/chat/send',
				body: {
					'chatId': chatId,
					'senderId': senderId,
					'text': message,
				},
				requiresAuth: true,
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
	socket = IO.io(EnvConfig.socketUrl, <String, dynamic>{
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
