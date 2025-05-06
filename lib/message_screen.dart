import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'AESHelper.dart';

class MessageScreen extends StatefulWidget {
  final String currentUserId;
  final String otherUserId;

  MessageScreen({required this.currentUserId, required this.otherUserId});

  @override
  _MessageScreenState createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ScrollController _scrollController = ScrollController();

  late String chatId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    chatId = getChatId(widget.currentUserId, widget.otherUserId);
    markMessagesAsRead();
  }

  String getChatId(String user1, String user2) {
    return user1.hashCode <= user2.hashCode
        ? '${user1}_$user2'
        : '${user2}_$user1';
  }

  void markMessagesAsRead() async {
    await _firestore.collection('chats').doc(chatId).set({
      'unreadCount': {
        widget.currentUserId: 0,
      }
    }, SetOptions(merge: true));
  }

  void sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    String encryptedMessage = AESHelper.encryptMessage(message);

    await _firestore.collection('chats').doc(chatId).set({
      'participants': [widget.currentUserId, widget.otherUserId],
      'lastMessage': encryptedMessage,
      'timestamp': Timestamp.now(),
      'unreadCount': {
        widget.otherUserId: FieldValue.increment(1),
      }
    }, SetOptions(merge: true));

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'senderId': widget.currentUserId,
      'receiverId': widget.otherUserId,
      'text': encryptedMessage,
      'timestamp': Timestamp.now(),
    });

    _messageController.clear();
    _scrollController.animateTo(
      0.0,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() => _isLoading = true);

      File image = File(pickedFile.path);
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref = _storage.ref().child('chat_images').child(fileName);
      UploadTask uploadTask = ref.putFile(image);
      TaskSnapshot snapshot = await uploadTask;
      String imageUrl = await snapshot.ref.getDownloadURL();

      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': widget.currentUserId,
        'receiverId': widget.otherUserId,
        'imageUrl': imageUrl,
        'timestamp': Timestamp.now(),
      });

      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var message = messages[index];
                    bool isMe = message['senderId'] == widget.currentUserId;
                    String text = message.data().toString().contains('text')
                        ? AESHelper.decryptMessage(message['text'])
                        : '';
                    String imageUrl =
                        message.data().toString().contains('imageUrl')
                            ? message['imageUrl']
                            : '';

                    return Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          if (text.isNotEmpty)
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.blue : Colors.grey[300],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                text,
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                          if (imageUrl.isNotEmpty)
                            Container(
                              margin: EdgeInsets.only(top: 5),
                              child: Image.network(imageUrl, width: 200),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_isLoading) LinearProgressIndicator(),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.photo),
                onPressed: pickImage,
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(hintText: 'Type a message'),
                ),
              ),
              IconButton(
                icon: Icon(Icons.send),
                onPressed: () => sendMessage(_messageController.text),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
