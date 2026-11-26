import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../config/app_config.dart';

class HomeScreen extends StatefulWidget {
  final bool darkMode;
  final ValueChanged<bool> onThemeChanged;
  const HomeScreen({super.key, required this.darkMode, required this.onThemeChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _tab = 0;
  int _coins = 0;
  int _adsToday = 0;
  int _quizCorrect = 0;
  int _quizWrong = 0;
  int _quizIdx = 0;
  bool _quizAnswered = false;
  String _quizFeedback = '';
  String _myReferCode = 'KJ-USER99';
  bool _referralClaimed = false;
  RewardedAd? _rewardedAd;

  late AnimationController _wheelCtrl;
  double _currentAngle = 0;
  double _targetAngle = 0;
  bool _isSpinning = false;
  int _activeSeconds = 0;
  Timer? _timer;

  final List<int> _spinValues = [10, 20, 30, 40, 50];
  final List<Color> _spinColors = const [
    Color(0xFF10B981),
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
  ];

  final List<String> _tttBoard = List.filled(9, '');
  bool _tttOver = false;
  String _tttStatus = '';

  final _upiCtrl = TextEditingController();
  final _referInputCtrl = TextEditingController();
  int _selectedWithdrawAmt = 10;

  final List> _quizQuestions = [
    {'q': '1. In which year did India win its first Cricket World Cup?', 'opts': ['1979', '1983', '1987', '2007'], 'ans': 1},
    {'q': '2. What is the full form of UPI?', 'opts': ['Unified Payments Interface', 'Universal Pay India', 'Unique Payment ID', 'United Pay Integration'], 'ans': 0},
    {'q': '3. Which is the longest sea bridge in India?', 'opts': ['Bandra-Worli Sea Link', 'Atal Setu (MTHL)', 'Pamban Bridge', 'Howrah Bridge'], 'ans': 1},
    {'q': '4. What is Gabbar Singh\'s famous dialogue in Sholay?', 'opts': ['Mogambo khush hua', 'Kitne aadmi the?', 'Mere paas maa hai', 'Pushpa, I hate tears'], 'ans': 1},
    {'q': '5. What gets wetter the more it dries?', 'opts': ['The Sun', 'A Towel', 'Ice', 'Wind'], 'ans': 1},
    {'q': '6. Who scored the very first century in IPL history?', 'opts': ['Virat Kohli', 'Sachin Tendulkar', 'Brendon McCullum', 'Rohit Sharma'], 'ans': 2},
    {'q': '7. Which country is the largest democracy in the world?', 'opts': ['USA', 'India', 'Japan', 'UK'], 'ans': 1},
    {'q': '8. Which Indian city is known as the Pink City?', 'opts': ['Udaipur', 'Jodhpur', 'Jaipur', 'Bikaner'], 'ans': 2},
    {'q': '9. On which part of the Moon did Chandrayaan-3 land?', 'opts': ['North Pole', 'South Pole', 'Equator', 'East Side'], 'ans': 1},
    {'q': '10. Which Indian cricketer is known as Captain Cool?', 'opts': ['Kapil Dev', 'Sourav Ganguly', 'MS Dhoni', 'Virat Kohli'], 'ans': 2},
    {'q': '11. What was Aamir Khan\'s character\'s real name in 3 Idiots?', 'opts': ['Ranchhoddas', 'Phunsukh Wangdu', 'Farhan', 'Raju'], 'ans': 1},
    {'q': '12. Which is the strongest bone in the human body?', 'opts': ['Arm', 'Femur (Thigh)', 'Ear', 'Finger'], 'ans': 1},
    {'q': '13. Which fruit has its seeds on the outside?', 'opts': ['Apple', 'Strawberry', 'Mango', 'Banana'], 'ans': 1},
    {'q': '14. Which planet is known as the Red Planet?', 'opts': ['Venus', 'Mars', 'Jupiter', 'Saturn'], 'ans': 1},
    {'q': '15. If you overtake the person in 2nd place, what place are you in?', 'opts': ['1st Place', '2nd Place', '3rd Place', '4th Place'], 'ans': 1},
  ];

  @override
  void initState() {
    super.initState();
    _wheelCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..addListener(() {
        setState(() {
          final t = Curves.easeOutCubic.transform(_wheelCtrl.value);
          _currentAngle = _currentAngle + (_targetAngle - _currentAngle) * t * 0.15;
        });
      });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _activeSeconds++);
    });
    _loadUserData();
    _loadRewardedAd();
  }

  @override
  void dispose() {
    _wheelCtrl.dispose();
    _timer?.cancel();
    _upiCtrl.dispose();
    _referInputCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _coins = (doc.data()?['coins'] ?? 0) as int;
          _adsToday = (doc.data()?['adsWatchedToday'] ?? 0) as int;
          _myReferCode = (doc.data()?['myReferCode'] ?? 'KJ-USER99') as String;
          _referralClaimed = (doc.data()?['referralClaimed'] ?? false) as bool;
        });
      }
    } catch (_) {}
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: AppConfig.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (_) => _rewardedAd = null,
      ),
    );
  }

  void _showRewardedAd(VoidCallback onReward) {
    if (_adsToday >= AppConfig.maxDailyAds) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Daily limit (12 Ads) reached!')));
      return;
    }
    if (_rewardedAd == null) {
      _loadRewardedAd();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ad loading... tap again in 2 seconds.')));
      return;
    }
    _rewardedAd!.show(onUserEarnedReward: (_, __) {
      setState(() => _adsToday += 1);
      onReward();
      _loadRewardedAd();
    });
  }

  Future<void> _addCoins(int amount) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _coins += amount);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'coins': FieldValue.increment(amount),
        'adsWatchedToday': _adsToday,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _spinWheel() async {
    if (_isSpinning) return;
    setState(() => _isSpinning = true);
    final idx = Random().nextInt(_spinValues.length);
    _targetAngle = _currentAngle + (pi * 10) + (idx * (2 * pi / _spinValues.length));
    _wheelCtrl.reset();
    await _wheelCtrl.forward();
    setState(() => _isSpinning = false);
    final won = _spinValues[idx];
    _showRewardedAd(() => _addCoins(won));
  }

  String _format12HrCountdown() {
    final now = DateTime.now();
    final remSec = (11 - (now.hour % 12)) * 3600 + (59 - now.minute) * 60 + (59 - now.second);
    final hh = (remSec ~/ 3600).toString().padLeft(2, '0');
    final mm = ((remSec % 3600) ~/ 60).toString().padLeft(2, '0');
    final ss = (remSec % 60).toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  String _formatActiveTime() {
    final m = (_activeSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_activeSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final rupees = (_coins / AppConfig.coinsPerRupee).toStringAsFixed(2);
    final q = _quizQuestions[_quizIdx % _quizQuestions.length];

    return Scaffold(
      body: Column(
        children: [
          // Colourful Emerald Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 44, 20, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF047857), Color(0xFF065F46)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('KHELO & JEETO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.6)),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
                          child: Text(_formatActiveTime(), style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace')),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
                          child: Text('Ads: $_adsToday/${AppConfig.maxDailyAds}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Your Coin Wallet', style: TextStyle(color: Color(0xFFA7F3D0), fontSize: 12)),
                        Text('$_coins Coins', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                        Text('Value: ₹$rupees (200 Coins = ₹1)', style: const TextStyle(color: Color(0xFFD1FAE5), fontSize: 12)),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showRewardedAd(() => _addCoins(50)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFBBF24),
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.play_circle_fill, size: 20),
                      label: const Text('+50 Coins\nWatch Ad', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main Tab Content
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                // TAB 0: GAMES
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.withOpacity(0.25)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(children: [
                            Icon(Icons.timer, size: 18, color: Color(0xFF059669)),
                            SizedBox(width: 6),
                            Text('12-Hr Bonus Reset:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ]),
                          Text(_format12HrCountdown(), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669), fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Colourful Spin Wheel Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Daily Spin & Win', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                Chip(label: Text('10–50 Coins', style: TextStyle(fontSize: 11))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Icon(Icons.arrow_drop_down, size: 32, color: Colors.black87),
                            SizedBox(
                              width: 190,
                              height: 190,
                              child: Transform.rotate(
                                angle: _currentAngle,
                                child: CustomPaint(
                                  painter: _WheelPainter(_spinValues, _spinColors),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _isSpinning ? null : _spinWheel,
                                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                                child: Text(_isSpinning ? 'Spinning...' : 'Spin Now'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Tic-Tac-Toe Medium Mode
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Tic-Tac-Toe (Medium)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                Text('Win: +30 Coins', style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: SizedBox(
                                width: 210,
                                child: GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: 9,
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8),
                                  itemBuilder: (_, i) => ElevatedButton(
                                    onPressed: _tttOver || _tttBoard[i].isNotEmpty ? null : () => _playTtt(i),
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: Text(
                                      _tttBoard[i],
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: _tttBoard[i] == 'X' ? const Color(0xFF059669) : const Color(0xFFE11D48),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (_tttStatus.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Center(child: Text(_tttStatus, style: const TextStyle(fontWeight: FontWeight.w600))),
                            ],
                            if (_tttOver) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: () => setState(() {
                                    _tttBoard.fillRange(0, 9, '');
                                    _tttOver = false;
                                    _tttStatus = '';
                                  }),
                                  child: const Text('Play Again'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 15-Question English Quiz
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Cricket & GK Quiz', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                Text('Correct: $_quizCorrect | Wrong: $_quizWrong', style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(q['q'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 10),
                            ...(q['opts'] as List<String>).asMap().entries.map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: OutlinedButton(
                                onPressed: _quizAnswered ? null : () {
                                  setState(() => _quizAnswered = true);
                                  if (e.key == q['ans']) {
                                    setState(() {
