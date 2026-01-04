import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_svg/flutter_svg.dart';import 'package:lendly/widgets/app_image.dart';import 'dart:convert';
import 'package:http/http.dart' as http;

class Message {
  final String from;
  final String message;
  final int timestamp;
  Message({required this.from, required this.message, required this.timestamp});
}

class ChatScreen extends StatefulWidget {
  final String name;
  final String contextLabel;
  final String avatarUrl;
  final bool isGroup;
  final bool trust;
  final String currentUid;
  final String peerUid;
  const ChatScreen({
    super.key,
    required this.name,
    required this.contextLabel,
    required this.avatarUrl,
    required this.currentUid,
    required this.peerUid,
    this.isGroup = false,
    this.trust = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

// Robust avatar widget for both asset and network images
class RobustAvatar extends StatelessWidget {
  final String? url;
  final double radius;
  const RobustAvatar({Key? key, this.url, this.radius = 20}) : super(key: key);

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
     child: ClipOval(
        child: Image.network(
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

class _ChatScreenState extends State<ChatScreen> {
  late IO.Socket socket;
  final TextEditingController _controller = TextEditingController();
  List<Message> messages = [];
  bool isLoadingMessages = true;
  bool isSendingMessage = false;

  String get roomId {
    if (widget.isGroup) {
      print('DEBUG: Using group chatId: ${widget.peerUid}');
      return widget.peerUid;
    } else {
      final uids = [widget.currentUid, widget.peerUid]..sort();
      print('DEBUG: Using personal chatId: ${uids[0]}_${uids[1]}');
      return '${uids[0]}_${uids[1]}';
    }
  }

  @override
  void initState() {
    super.initState();
    connectSocket();
    loadChatHistory(); // Load previous messages
  }

  Future<void> loadChatHistory() async {
    setState(() {
      isLoadingMessages = true;
    });
    try {
      final response = await http.get(
        Uri.parse('https://ary-lendly-production.up.railway.app/chat/messages/$roomId'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List messagesData = data['messages'] ?? [];
        setState(() {
          messages = messagesData.map((msg) => Message(
            from: msg['senderId'],
            message: msg['text'],
            timestamp: msg['createdAt'] is Map ? msg['createdAt']['_seconds'] * 1000 : 
                      msg['createdAt'] is String ? DateTime.parse(msg['createdAt']).millisecondsSinceEpoch :
                      DateTime.now().millisecondsSinceEpoch,
          )).toList();
          isLoadingMessages = false;
        });
        print('DEBUG: Loaded ${messages.length} messages from chat history');
      }
    } catch (e) {
      print('DEBUG: Failed to load chat history: $e');
      setState(() {
        isLoadingMessages = false;
      });
    }
  }

  void connectSocket() {
    socket = IO.io('https://ary-lendly-production.up.railway.app', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    socket.connect();
    socket.onConnect((_) {
      socket.emit('joinRoom', roomId);
    });
    socket.on('receiveMessage', (data) {
      setState(() {
        messages.add(Message(
          from: data['from'],
          message: data['message'],
          timestamp: data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
        ));
      });
    });
  }

  void sendMessage() {
    if (_controller.text.trim().isEmpty || isSendingMessage) return;
    setState(() {
      isSendingMessage = true;
    });
    final messageText = _controller.text.trim();
    final msg = {
      'roomId': roomId,
      'from': widget.currentUid,
      'to': widget.peerUid,
      'message': messageText,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    socket.emit('sendMessage', msg);
    // Don't add message here - let socket receiveMessage handle it to avoid duplication
    _controller.clear();
    // Also save to backend for persistence
    _saveMessageToBackend(messageText);
  }

  Future<void> _saveMessageToBackend(String messageText) async {
    try {
      await http.post(
        Uri.parse('https://ary-lendly-production.up.railway.app/chat/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chatId': roomId,
          'senderId': widget.currentUid,
          'text': messageText,
        }),
      );
      print('DEBUG: Message saved to backend');
    } catch (e) {
      print('DEBUG: Failed to save message to backend: $e');
    } finally {
      setState(() {
        isSendingMessage = false;
      });
    }
  }

  @override
  void dispose() {
    socket.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1a237e)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            RobustAvatar(url: widget.avatarUrl, radius: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(widget.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF1a237e))),
                      if (widget.trust)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(Icons.verified, color: Color(0xFF1DBF73), size: 18),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F9F1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.isGroup ? 'Group' : 'Direct Chat',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF1DBF73), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline, color: Color(0xFF1a237e)),
              onPressed: () {},
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoadingMessages
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1DBF73)),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Loading messages...',
                          style: TextStyle(
                            color: Color(0xFF1a237e),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : messages.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Start the conversation!',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isMe = msg.from == widget.currentUid;
                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: EdgeInsets.only(bottom: 8, left: isMe ? 40 : 0, right: isMe ? 0 : 40),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? const Color(0xFF1DBF73) : const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
                                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
                                ),
                              ),
                              child: Text(msg.message, style: TextStyle(color: isMe ? Colors.white : const Color(0xFF1a237e), fontSize: 15)),
                            ),
                          );
                        },
                      ),
          ),
          // Message input area
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file, color: Color(0xFF1a237e)),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                      ),
                      builder: (context) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.image, color: Color(0xFF1DBF73)),
                              title: const Text('Photo'),
                              onTap: () async {
                                Navigator.pop(context);
                                final ImagePicker picker = ImagePicker();
                                final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                                if (image != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Selected image: \\${image.name}')),
                                  );
                                  // TODO: Handle the selected image
                                }
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.camera_alt, color: Color(0xFF1DBF73)),
                              title: const Text('Camera'),
                              onTap: () async {
                                Navigator.pop(context);
                                final ImagePicker picker = ImagePicker();
                                final XFile? photo = await picker.pickImage(source: ImageSource.camera);
                                if (photo != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Captured photo: \\${photo.name}')),
                                  );
                                  // TODO: Handle the captured photo
                                }
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.insert_drive_file, color: Color(0xFF1DBF73)),
                              title: const Text('File'),
                              onTap: () async {
                                Navigator.pop(context);
                                final result = await FilePicker.platform.pickFiles();
                                if (result != null && result.files.isNotEmpty) {
                                  final file = result.files.first;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Selected file: \\${file.name}')),
                                  );
                                  // TODO: Handle the selected file
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Type a message…',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Color(0xFF1DBF73),
                  child: isSendingMessage
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: sendMessage,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
