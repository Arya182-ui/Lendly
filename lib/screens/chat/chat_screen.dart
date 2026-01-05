import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';
import 'dart:async';
import '../../services/enhanced_chat_service.dart';
import '../../services/session_service.dart';
import '../../config/env_config.dart';

class EnhancedChatScreen extends StatefulWidget {
  final String chatId;
  final String peerUid;
  final String peerName;
  final String peerAvatar;
  final bool isGroup;
  
  const EnhancedChatScreen({
    super.key,
    required this.chatId,
    required this.peerUid,
    required this.peerName,
    required this.peerAvatar,
    this.isGroup = false,
  });

  @override
  State<EnhancedChatScreen> createState() => _EnhancedChatScreenState();
}

class _EnhancedChatScreenState extends State<EnhancedChatScreen> 
    with WidgetsBindingObserver {
  late IO.Socket socket;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  
  List<ChatMessage> messages = [];
  String? currentUid;
  bool isLoading = true;
  bool isSending = false;
  bool isTyping = false;
  Set<String> typingUsers = {};
  Timer? _typingTimer;
  String? editingMessageId;
  bool isOnline = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _typingTimer?.cancel();
    socket.disconnect();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _markMessagesAsRead();
    }
  }

  Future<void> _initializeChat() async {
    try {
      currentUid = await SessionService.getUid();
      if (currentUid == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Authentication required')),
          );
          Navigator.pop(context);
        }
        return;
      }
      
      await _loadMessages();
      await _connectSocket();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize chat: $e')),
        );
      }
    }
  }

  Future<void> _loadMessages() async {
    try {
      final messagesData = await _chatService.getMessages(widget.chatId);
      if (mounted) {
        setState(() {
          messages = messagesData.map((msg) => ChatMessage.fromMap(msg)).toList();
          isLoading = false;
        });
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
          _markMessagesAsRead();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load messages: $e')),
        );
      }
    }
  }

  Future<void> _connectSocket() async {
    try {
      final token = await SessionService.getToken();
      
      socket = IO.io(EnvConfig.socketUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'auth': {
          'token': token ?? '',
        }
      });

      socket.connect();

      socket.onConnect((_) {
        debugPrint('Socket connected');
        socket.emit('joinRoom', widget.chatId);
      });

      socket.onDisconnect((_) {
        debugPrint('Socket disconnected');
      });

      // Acknowledge message sent
      socket.on('messageSent', (data) {
        if (mounted) {
          final messageId = data['messageId'];
          final messageIndex = messages.indexWhere((m) => m.id == messageId);
          if (messageIndex != -1 && messages[messageIndex].status == ChatService.STATUS_SENDING) {
            setState(() {
              messages[messageIndex] = ChatMessage(
                id: messages[messageIndex].id,
                senderId: messages[messageIndex].senderId,
                text: messages[messageIndex].text,
                type: messages[messageIndex].type,
                createdAt: messages[messageIndex].createdAt,
                status: ChatService.STATUS_SENT,
                deleted: messages[messageIndex].deleted,
                edited: messages[messageIndex].edited,
                editedAt: messages[messageIndex].editedAt,
                reactions: messages[messageIndex].reactions,
              );
            });
          }
        }
      });

      // Receive new messages
      socket.on('receiveMessage', (data) {
        if (mounted) {
          print('Received message data: $data'); // Debug log
          final message = ChatMessage.fromMap(data);
          print('Parsed message createdAt: ${message.createdAt}'); // Debug log
          if (!messages.any((m) => m.id == message.id)) {
            setState(() {
              messages.add(message);
            });
            _scrollToBottom();
            if (message.senderId != currentUid) {
              _markMessagesAsRead();
            }
          }
        }
      });

      // Handle typing indicators
      socket.on('userTyping', (data) {
        if (mounted && data['userId'] != currentUid) {
          setState(() {
            if (data['isTyping'] == true) {
              typingUsers.add(data['userId']);
            } else {
              typingUsers.remove(data['userId']);
            }
          });
        }
      });

      // Handle message status updates
      socket.on('messageStatus', (data) {
        if (mounted) {
          final messageId = data['messageId'];
          final status = data['status'];
          final messageIndex = messages.indexWhere((m) => m.id == messageId);
          if (messageIndex != -1) {
            setState(() {
              messages[messageIndex] = ChatMessage(
                id: messages[messageIndex].id,
                senderId: messages[messageIndex].senderId,
                text: messages[messageIndex].text,
                type: messages[messageIndex].type,
                createdAt: messages[messageIndex].createdAt,
                status: status,
                deleted: messages[messageIndex].deleted,
                edited: messages[messageIndex].edited,
                editedAt: messages[messageIndex].editedAt,
                reactions: messages[messageIndex].reactions,
              );
            });
          }
        }
      });

      // Handle message deletion
      socket.on('messageDeleted', (data) {
        if (mounted) {
          final messageIndex = messages.indexWhere((m) => m.id == data['messageId']);
          if (messageIndex != -1) {
            setState(() {
              messages[messageIndex] = ChatMessage(
                id: messages[messageIndex].id,
                senderId: messages[messageIndex].senderId,
                text: '[Message deleted]',
                type: messages[messageIndex].type,
                createdAt: messages[messageIndex].createdAt,
                status: messages[messageIndex].status,
                deleted: true,
              );
            });
          }
        }
      });

      // Handle message editing
      socket.on('messageEdited', (data) {
        if (mounted) {
          final messageIndex = messages.indexWhere((m) => m.id == data['messageId']);
          if (messageIndex != -1) {
            setState(() {
              messages[messageIndex] = ChatMessage(
                id: messages[messageIndex].id,
                senderId: messages[messageIndex].senderId,
                text: data['newText'] ?? messages[messageIndex].text,
                type: messages[messageIndex].type,
                createdAt: messages[messageIndex].createdAt,
                status: messages[messageIndex].status,
                deleted: messages[messageIndex].deleted,
                edited: true,
                editedAt: DateTime.now(),
              );
            });
          }
        }
      });

      // Handle user online status
      socket.on('userOnlineStatus', (data) {
        if (mounted && data['userId'] == widget.peerUid) {
          setState(() {
            isOnline = data['isOnline'] ?? false;
          });
        }
      });

    } catch (e) {
      debugPrint('Socket connection failed: $e');
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty || isSending || currentUid == null) return;

    setState(() {
      isSending = true;
    });

    final messageId = 'msg_${DateTime.now().millisecondsSinceEpoch}_${currentUid!.substring(0, 6)}';
    final tempMessage = ChatMessage(
      id: messageId,
      senderId: currentUid!,
      text: text,
      type: 'text',
      createdAt: DateTime.now(),
      status: ChatService.STATUS_SENDING,
    );

    // Add temporary message to UI
    setState(() {
      messages.add(tempMessage);
      _controller.clear();
    });
    
    _scrollToBottom();

    // Track if message was sent via socket
    bool sentViaSocket = false;
    
    // Timer to update status to SENT after 2 seconds if socket works
    Timer? statusTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && sentViaSocket) {
        setState(() {
          isSending = false;
          final messageIndex = messages.indexWhere((m) => m.id == messageId);
          if (messageIndex != -1 && messages[messageIndex].status == ChatService.STATUS_SENDING) {
            messages[messageIndex] = ChatMessage(
              id: messageId,
              senderId: currentUid!,
              text: text,
              type: 'text',
              createdAt: DateTime.now(),
              status: ChatService.STATUS_SENT,
            );
          }
        });
      }
    });

    // Send via socket (primary method)
    try {
      socket.emit('sendMessage', {
        'messageId': messageId,
        'roomId': widget.chatId,
        'to': widget.peerUid,
        'message': text,
        'type': 'text',
        'createdAt': DateTime.now().millisecondsSinceEpoch, // Send timestamp
      });
      sentViaSocket = true;
    } catch (e) {
      print('Socket send failed: $e');
      sentViaSocket = false;
    }

    // Fallback: send via REST API (only if socket fails)
    if (!sentViaSocket) {
      _chatService.sendMessage(
        chatId: widget.chatId,
        senderId: currentUid!,
        text: text,
      ).then((response) {
        statusTimer?.cancel();
        if (mounted) {
          setState(() {
            isSending = false;
            final messageIndex = messages.indexWhere((m) => m.id == messageId);
            if (messageIndex != -1) {
              messages[messageIndex] = ChatMessage(
                id: messageId,
                senderId: currentUid!,
                text: text,
                type: 'text',
                createdAt: DateTime.now(),
                status: ChatService.STATUS_SENT,
              );
            }
          });
        }
      }).catchError((error) {
        statusTimer?.cancel();
        print('REST API send failed: $error');
        if (mounted) {
          setState(() {
            isSending = false;
            final messageIndex = messages.indexWhere((m) => m.id == messageId);
            if (messageIndex != -1) {
              messages[messageIndex] = ChatMessage(
                id: messageId,
                senderId: currentUid!,
                text: text,
                type: 'text',
                createdAt: DateTime.now(),
                status: ChatService.STATUS_FAILED,
              );
            }
          });
        }
      });
    } else {
      // Socket sent successfully, just reset isSending flag
      setState(() {
        isSending = false;
      });
    }
  }

  void _onTypingChanged(String text) {
    if (text.isNotEmpty && !isTyping) {
      setState(() {
        isTyping = true;
      });
      socket.emit('startTyping', {
        'roomId': widget.chatId,
        'to': widget.peerUid,
      });
    }

    // Reset typing timer
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 1), () {
      if (isTyping) {
        setState(() {
          isTyping = false;
        });
        socket.emit('stopTyping', {
          'roomId': widget.chatId,
        });
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _markMessagesAsRead() {
    if (currentUid != null) {
      _chatService.markMessagesRead(widget.chatId, currentUid!);
    }
  }

  void _showMessageOptions(ChatMessage message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.senderId == currentUid && !message.deleted) ...[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Message'),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Message'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message);
                },
              ),
            ],
            if (!message.deleted) ...[
              ListTile(
                leading: const Icon(Icons.add_reaction),
                title: const Text('Add Reaction'),
                onTap: () {
                  Navigator.pop(context);
                  _showReactionPicker(message);
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy Text'),
              onTap: () async {
                Navigator.pop(context);
                await Clipboard.setData(ClipboardData(text: message.text));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Text copied to clipboard')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _editMessage(ChatMessage message) {
    _controller.text = message.text;
    setState(() {
      editingMessageId = message.id;
    });
  }

  void _handleMessageEdit() async {
    final newText = _controller.text.trim();
    if (newText.isEmpty || editingMessageId == null || currentUid == null) return;

    try {
      await _chatService.editMessage(
        chatId: widget.chatId,
        messageId: editingMessageId!,
        userId: currentUid!,
        newText: newText,
      );
      
      // Update local message
      setState(() {
        final messageIndex = messages.indexWhere((m) => m.id == editingMessageId);
        if (messageIndex != -1) {
          messages[messageIndex] = ChatMessage(
            id: messages[messageIndex].id,
            senderId: messages[messageIndex].senderId,
            text: newText,
            type: messages[messageIndex].type,
            createdAt: messages[messageIndex].createdAt,
            status: messages[messageIndex].status,
            deleted: messages[messageIndex].deleted,
            edited: true,
            editedAt: DateTime.now(),
          );
        }
        editingMessageId = null;
        _controller.clear();
      });
      
      // Emit socket event for real-time update
      socket.emit('editMessage', {
        'roomId': widget.chatId,
        'messageId': editingMessageId,
        'newText': newText,
      });
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to edit message: $e')),
        );
      }
    }
  }

  void _deleteMessage(ChatMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _chatService.deleteMessage(
                  chatId: widget.chatId,
                  messageId: message.id,
                  userId: currentUid!,
                );
                
                // Also emit socket event for real-time update
                socket.emit('deleteMessage', {
                  'roomId': widget.chatId,
                  'messageId': message.id,
                });
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete message: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showReactionPicker(ChatMessage message) {
    const reactions = ['👍', '👎', '❤️', '😂', '😢', '😮', '😡', '👏'];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Reaction'),
        content: Wrap(
          children: reactions.map((reaction) => 
            GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                try {
                  await _chatService.addReaction(
                    chatId: widget.chatId,
                    messageId: message.id,
                    userId: currentUid!,
                    reaction: reaction,
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to add reaction: $e')),
                    );
                  }
                }
              },
              child: Container(
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(reaction, style: const TextStyle(fontSize: 24)),
              ),
            ),
          ).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildMessageList(),
          ),
          _buildTypingIndicator(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: widget.isGroup ? const Color(0xFFF3E8FF) : Colors.white,
      elevation: 0.5,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: widget.isGroup ? const Color(0xFF7C3AED) : const Color(0xFF1a237e)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Stack(
            children: [
              _buildAvatar(widget.peerAvatar, 20),
              // Type indicator badge
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: widget.isGroup ? const Color(0xFF7C3AED) : const Color(0xFF1DBF73),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Icon(
                    widget.isGroup ? Icons.group : Icons.person,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      widget.isGroup ? Icons.group_rounded : Icons.person_outline_rounded,
                      size: 14,
                      color: widget.isGroup ? const Color(0xFF7C3AED) : const Color(0xFF1DBF73),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.peerName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: widget.isGroup ? const Color(0xFF7C3AED) : const Color(0xFF1a237e),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.isGroup ? const Color(0xFF7C3AED).withValues(alpha: 0.15) : const Color(0xFF1DBF73).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.isGroup ? 'Group Chat' : 'Direct Chat',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: widget.isGroup ? const Color(0xFF7C3AED) : const Color(0xFF1DBF73),
                        ),
                      ),
                    ),
                    if (!widget.isGroup) ...[
                      const SizedBox(width: 6),
                      Text(
                        isOnline ? '● Online' : '○ Offline',
                        style: TextStyle(
                          fontSize: 11,
                          color: isOnline ? Colors.green[600] : Colors.grey[500],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.info_outline, color: widget.isGroup ? const Color(0xFF7C3AED) : const Color(0xFF1a237e)),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Row(
                  children: [
                    Icon(
                      widget.isGroup ? Icons.group_rounded : Icons.person_rounded,
                      color: widget.isGroup ? const Color(0xFF7C3AED) : const Color(0xFF1DBF73),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.isGroup ? 'Group Info' : 'Chat with ${widget.peerName}',
                        style: TextStyle(
                          color: widget.isGroup ? const Color(0xFF7C3AED) : const Color(0xFF1a237e),
                        ),
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.isGroup ? const Color(0xFFF3E8FF) : const Color(0xFFE8F9F1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Type: ${widget.isGroup ? "Group" : "Personal"}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text('Chat ID: ${widget.chatId}'),
                          const SizedBox(height: 4),
                          Text('Peer ID: ${widget.peerUid}'),
                          const SizedBox(height: 4),
                          Text('Messages: ${messages.length}'),
                          if (!widget.isGroup) ...[
                            const SizedBox(height: 4),
                            Text('Status: ${isOnline ? "Online" : "Offline"}'),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAvatar(String? url, double radius) {
    if (url == null || url.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.green[700],
        child: Icon(Icons.person, color: Colors.white, size: radius),
      );
    }
    
    if (url.endsWith('.svg')) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[200],
        child: ClipOval(
          child: SvgPicture.asset(
            url,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            placeholderBuilder: (context) => Icon(
              Icons.person, 
              color: Colors.green[700], 
              size: radius,
            ),
          ),
        ),
      );
    }
    
    return CircleAvatar(
      radius: radius,
      backgroundImage: AssetImage(url),
      backgroundColor: Colors.grey[200],
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isMe = message.senderId == currentUid;
        final showAvatar = index == messages.length - 1 ||
            messages[index + 1].senderId != message.senderId;
        
        return _buildMessageBubble(message, isMe, showAvatar);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe, bool showAvatar) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showAvatar)
            _buildAvatar(widget.peerAvatar, 16)
          else if (!isMe)
            const SizedBox(width: 32),
          
          if (!isMe) const SizedBox(width: 8),
          
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showMessageOptions(message),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFF1DBF73) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.deleted)
                      Text(
                        message.text,
                        style: TextStyle(
                          color: isMe ? Colors.white70 : Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    else
                      Text(
                        message.text,
                        style: TextStyle(
                          color: isMe ? Colors.white : Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                    
                    const SizedBox(height: 4),
                    
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.createdAt),
                          style: TextStyle(
                            color: isMe ? Colors.white70 : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        
                        if (message.edited)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              '(edited)',
                              style: TextStyle(
                                color: isMe ? Colors.white70 : Colors.grey,
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          _buildMessageStatusIcon(message.status),
                        ],
                      ],
                    ),
                    
                    // Reactions
                    if (message.hasReactions)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _buildReactions(message.reactions!),
                      ),
                  ],
                ),
              ),
            ),
          ),
          
          if (isMe) const SizedBox(width: 8),
          
          if (isMe && showAvatar)
            _buildAvatar(null, 16) // Current user avatar
          else if (isMe)
            const SizedBox(width: 32),
        ],
      ),
    );
  }

  Widget _buildMessageStatusIcon(String status) {
    IconData icon;
    Color color;
    
    switch (status) {
      case ChatService.STATUS_SENDING:
        icon = Icons.access_time;
        color = Colors.white70;
        break;
      case ChatService.STATUS_SENT:
        icon = Icons.check;
        color = Colors.white70;
        break;
      case ChatService.STATUS_DELIVERED:
        icon = Icons.done_all;
        color = Colors.white70;
        break;
      case ChatService.STATUS_READ:
        icon = Icons.done_all;
        color = Colors.blue;
        break;
      case ChatService.STATUS_FAILED:
        icon = Icons.error;
        color = Colors.red;
        break;
      default:
        return const SizedBox.shrink();
    }
    
    return Icon(
      icon,
      size: 14,
      color: color,
    );
  }

  Widget _buildReactions(Map<String, List<String>> reactions) {
    return Wrap(
      spacing: 4,
      children: reactions.entries.map((entry) {
        final emoji = entry.key;
        final users = entry.value;
        final hasMyReaction = users.contains(currentUid);
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: hasMyReaction ? Colors.blue[100] : Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
            border: hasMyReaction 
                ? Border.all(color: Colors.blue) 
                : null,
          ),
          child: Text(
            '$emoji ${users.length}',
            style: const TextStyle(fontSize: 12),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTypingIndicator() {
    if (typingUsers.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildAvatar(widget.peerAvatar, 12),
          const SizedBox(width: 8),
          Text(
            '${widget.peerName} is typing...',
            style: TextStyle(
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: _controller,
                  onChanged: _onTypingChanged,
                  onSubmitted: (_) => editingMessageId != null ? _handleMessageEdit() : _sendMessage(),
                  decoration: InputDecoration(
                    hintText: editingMessageId != null 
                        ? 'Edit message...' 
                        : 'Type a message...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    prefixIcon: editingMessageId != null
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                editingMessageId = null;
                                _controller.clear();
                              });
                            },
                          )
                        : null,
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1DBF73),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  editingMessageId != null ? Icons.check : Icons.send,
                  color: Colors.white,
                ),
                onPressed: isSending ? null : () {
                  if (editingMessageId != null) {
                    _handleMessageEdit();
                  } else {
                    _sendMessage();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${dateTime.day}/${dateTime.month}';
    } else {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}