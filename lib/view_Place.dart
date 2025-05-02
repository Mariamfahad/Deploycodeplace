import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'bookmark_service.dart';
import 'create_post_page.dart';
import 'review_widget.dart';
import 'package:rating_summary/rating_summary.dart';

class ViewPlace extends StatefulWidget {
  final String place_Id;

  const ViewPlace({super.key, required this.place_Id});

  @override
  _PlaceScreenState createState() => _PlaceScreenState();
}

class _PlaceScreenState extends State<ViewPlace>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late String placeId;
  String _placeName = 'Loading...';
  String _description = 'No description available';
  String _category = '';
  String _subcategory = '';
  String _imageUrl = '';

  bool isBookmarked = false;
  int _totalReviews = 0;
  double _averageRating = 0.0;
  int _countFiveStars = 0;
  int _countFourStars = 0;
  int _countThreeStars = 0;
  int _countTwoStars = 0;
  int _countOneStars = 0;

  late TabController _tabController;
  @override
  void initState() {
    super.initState();
    placeId = widget.place_Id;

    if (placeId == 'unknown_id' || placeId == null || placeId!.isEmpty) {
      debugPrint("❌ Invalid placeId: $placeId");
      return;
    }

    _tabController = TabController(length: 2, vsync: this);
    _loadPlaceProfile();
    _checkIfBookmarked();
    _fetchRatingSummary();
  }

  Future<void> _loadPlaceProfile() async {
    try {
      DocumentSnapshot placeDoc =
          await _firestore.collection('places').doc(placeId).get();

      if (!placeDoc.exists) {
        debugPrint("❌ No place found with ID: $placeId");
        return;
      }

      var data = placeDoc.data() as Map<String, dynamic>;

      setState(() {
        _placeName = data['place_name'] ?? 'Unknown Place';
        _description = (data['description'] as String?)?.trim() ??
            'No description available';

        _category = data['category'] ?? 'Unknown';
        _subcategory = data['subcategory'] ?? '';
        _imageUrl = data['imageUrl'] ?? '';
      });
    } catch (e) {
      debugPrint("❌ Error loading place: $e");
    }
  }

  Future<void> _checkIfBookmarked() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final docSnapshot = await _firestore
        .collection('bookmarks')
        .doc(userId)
        .collection('places')
        .doc(placeId)
        .get();

    setState(() {
      isBookmarked = docSnapshot.exists;
    });
  }

  Future<void> _fetchRatingSummary() async {
    try {
      QuerySnapshot reviewsSnapshot = await _firestore
          .collection('Review')
          .where('placeId', isEqualTo: placeId)
          .get();

      int totalReviews = reviewsSnapshot.docs.length;
      int totalRatingSum = 0;
      int countFiveStars = 0;
      int countFourStars = 0;
      int countThreeStars = 0;
      int countTwoStars = 0;
      int countOneStars = 0;

      for (var doc in reviewsSnapshot.docs) {
        int rating = doc['Rating'] ?? 0;
        totalRatingSum += rating;

        switch (rating) {
          case 5:
            countFiveStars++;
            break;
          case 4:
            countFourStars++;
            break;
          case 3:
            countThreeStars++;
            break;
          case 2:
            countTwoStars++;
            break;
          case 1:
            countOneStars++;
            break;
          default:
            break;
        }
      }

      setState(() {
        _totalReviews = totalReviews;
        _averageRating = totalReviews > 0 ? totalRatingSum / totalReviews : 0.0;
        _countFiveStars = countFiveStars;
        _countFourStars = countFourStars;
        _countThreeStars = countThreeStars;
        _countTwoStars = countTwoStars;
        _countOneStars = countOneStars;
      });
    } catch (e) {
      debugPrint("❌ Failed to fetch rating summary: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (placeId == 'unknown_id' || placeId == null || placeId!.isEmpty) {
      return Scaffold(
        body: Center(child: Text("⚠️ No valid place ID provided!")),
      );
    }
    return Scaffold(
      appBar: AppBar(
          title: Text(_placeName.isNotEmpty ? _placeName : "Loading...")),
      body: Column(
        children: [
          _imageUrl.isNotEmpty
              ? Image.network(_imageUrl,
                  height: 200, width: 200, fit: BoxFit.cover)
              : Container(height: 200, width: 200, color: Colors.grey),
          TabBar(
              controller: _tabController,
              tabs: [Tab(text: "Overview"), Tab(text: "Reviews")]),
          Expanded(
            child: TabBarView(controller: _tabController, children: [
              Column(
                children: [
                  RatingSummary(
                    counter: _totalReviews,
                    average: double.parse(_averageRating.toStringAsFixed(1)),
                    counterFiveStars: _countFiveStars,
                    counterFourStars: _countFourStars,
                    counterThreeStars: _countThreeStars,
                    counterTwoStars: _countTwoStars,
                    counterOneStars: _countOneStars,
                  ),
                  Text(_description),
                ],
              ),
              Review_widget(place_Id: placeId!),
            ]),
          )
        ],
      ),
    );
  }
}
