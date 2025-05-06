import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'message_screen.dart';
import 'AESHelper.dart';

class MessageListScreen extends StatelessWidget {
  final String currentUserId;

  MessageListScreen({required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Messages'),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUserId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final chats = snapshot.data!.docs;
          if (chats.isEmpty) {
            return Center(child: Text('No conversations'));
          }

          return ListView(
            children: chats.map((doc) {
              final chatData = doc.data() as Map<String, dynamic>;
              final participants = chatData['participants'] as List;
              final otherUserId =
                  participants.firstWhere((id) => id != currentUserId);

              final rawLastMessage = chatData['lastMessage'] ?? '';
              final lastMessage = rawLastMessage.isNotEmpty
                  ? AESHelper.decryptMessage(rawLastMessage)
                  : '';

              final unreadMap = chatData['unreadCount'] ?? {};
              final unreadCount = unreadMap[currentUserId] ?? 0;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(otherUserId)
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                    return ListTile(
                      leading: CircleAvatar(child: Icon(Icons.person)),
                      title: Text('Unknown'),
                      subtitle: Text(lastMessage),
                    );
                  }

                  final otherUsername =
                      userSnapshot.data!['user_name'] ?? 'Unknown';

                  return ListTile(
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.pink.shade100,
                      child: Icon(Icons.person, color: Colors.brown),
                    ),
                    title: Text(otherUsername),
                    subtitle: Text(lastMessage),
                    trailing: unreadCount > 0
                        ? Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints:
                                BoxConstraints(minWidth: 20, minHeight: 20),
                            child: Text(
                              '$unreadCount',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : SizedBox(), // لو مافي رسائل غير مقروءة، ما يظهر شيء
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MessageScreen(
                            currentUserId: currentUserId,
                            otherUserId: otherUserId,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
