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
    {'q': '4. What is Gabbar Singh famous dialogue in Sholay?', 'opts': ['Mogambo khush hua', 'Kitne aadmi the?', 'Mere paas maa hai', 'Pushpa, I hate tears'], 'ans': 1},
    {'q': '5. What gets wetter the more it dries?', 'opts': ['The Sun', 'A Towel', 'Ice', 'Wind'], 'ans': 1},
    {'q': '6. Who scored the very first century in IPL history?', 'opts': ['Virat Kohli', 'Sachin Tendulkar', 'Brendon McCullum', 'Rohit Sharma'], 'ans': 2},
    {'q': '7. Which country is the largest democracy in the world?', 'opts': ['USA', 'India', 'Japan', 'UK'], 'ans': 1},
    {'q': '8. Which Indian city is known as the Pink City?', 'opts': ['Udaipur', 'Jodhpur', 'Jaipur', 'Bikaner'], 'ans': 2},
    {'q': '9. On which part of the Moon did Chandrayaan-3 land?', 'opts': ['North Pole', 'South Pole', 'Equator', 'East Side'], 'ans': 1},
    {'q': '10. Which Indian cricketer is known as Captain Cool?', 'opts': ['Kapil Dev', 'Sourav Ganguly', 'MS Dhoni', 'Virat Kohli'], 'ans': 2},
    {'q': '11. What was Aamir Khan character real name in 3 Idiots?', 'opts': ['Ranchhoddas', 'Phunsukh Wangdu', 'Farhan', 'Raju'], 'ans': 1},
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

  void _answerQuiz(int selectedIdx, int correctIdx) {
    if (_quizAnswered) return;
    setState(() {
      _quizAnswered = true;
      if (selectedIdx == correctIdx) {
        _quizCorrect++;
        _quizFeedback = 'Correct! Watch Ad completed for +25 Coins.';
      } else {
        _quizWrong++;
        _quizFeedback = 'Wrong Answer! Score record updated.';
      }
    });
    if (selectedIdx == correctIdx) {
      _showRewardedAd(() => _addCoins(25));
    }
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
    final opts = q['opts'] as List<String>;
    final ans = q['ans'] as int;

    return Scaffold(
      body: Column(
        children: [
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

          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
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
                            for (int i = 0; i < opts.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: OutlinedButton(
                                  onPressed: _quizAnswered ? null : () => _answerQuiz(i, ans),
                                  child: Align(alignment: Alignment.centerLeft, child: Text(opts[i])),
                                ),
                              ),
                            if (_quizFeedback.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(_quizFeedback, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 8),
                              FilledButton(
                                onPressed: () => setState(() {
                                  _quizIdx++;
                                  _quizAnswered = false;
                                  _quizFeedback = '';
                                }),
                                child: const Text('Next Question →'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('UPI Payment Withdraw (200 Coins = ₹1)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      TextField(controller: _upiCtrl, decoration: const InputDecoration(labelText: 'Enter UPI ID (e.g. name@okicici)', border: OutlineInputBorder())),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [10, 20, 30, 100].map((amt) => ChoiceChip(
                          label: Text('₹$amt'),
                          selected: _selectedWithdrawAmt == amt,
                          onSelected: (_) => setState(() => _selectedWithdrawAmt = amt),
                        )).toList(),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () async {
                          final needed = _selectedWithdrawAmt * AppConfig.coinsPerRupee;
                          if (_coins < needed || !_upiCtrl.text.contains('@')) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Need $needed Coins and a valid UPI ID.')));
                            return;
                          }
                          await FirebaseFirestore.instance.collection('withdrawals').add({
                            'uid': user?.uid,
                            'upiId': _upiCtrl.text.trim(),
                            'amountInr': _selectedWithdrawAmt,
                            'coins': needed,
                            'status': 'Pending',
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                          await _addCoins(-needed);
                          if (mounted) setState(() => _tab = 2);
                        },
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                        child: Text('Withdraw ₹$_selectedWithdrawAmt via UPI'),
                      ),
                    ],
                  ),
                ),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('withdrawals')
                      .where('uid', isEqualTo: user?.uid)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(child: Text('Could not load history: ${snap.error}'));
                    }
                    if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = List<QueryDocumentSnapshot>.from(snap.data?.docs ?? []);
                    docs.sort((a, b) {
                      final t1 = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                      final t2 = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                      return (t2?.millisecondsSinceEpoch ?? 0).compareTo(t1?.millisecondsSinceEpoch ?? 0);
                    });
                    if (docs.isEmpty) {
                      return const Center(child: Text('No UPI payouts yet. Withdraw ₹10+ from Withdraw tab.'));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final d = docs[i].data() as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                QrImageView(data: 'upi:${d['upiId']}|amt:${d['amountInr']}', size: 64, backgroundColor: Colors.white),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('UPI: ${d['upiId']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text('Status: ${d['status']}', style: const TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Text('₹${d['amountInr']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF059669))),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ListTile(
                      leading: const CircleAvatar(backgroundColor: Color(0xFF059669), child: Icon(Icons.mail, color: Colors.white)),
                      title: Text(user?.email ?? 'Not logged in', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Verified Gmail Account'),
                    ),
                    SwitchListTile(
                      title: const Text('Dark Mode (Eye Comfort)'),
                      value: widget.darkMode,
                      onChanged: widget.onThemeChanged,
                    ),
                    const Divider(),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your Referral Code: $_myReferCode', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Center(child: QrImageView(data: '${AppConfig.downloadBaseUrl}$_myReferCode', size: 100, backgroundColor: Colors.white)),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () => Share.share('Download Khelo & Jeeto and use code $_myReferCode for 500 Coins: ${AppConfig.downloadBaseUrl}$_myReferCode'),
                                icon: const Icon(Icons.share),
                                label: const Text('Share on WhatsApp'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(controller: _referInputCtrl, decoration: const InputDecoration(labelText: 'Enter Friend Code (KHELO500)', border: OutlineInputBorder())),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () async {
                                  if (_referralClaimed) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Referral already claimed!')));
                                    return;
                                  }
                                  if (_referInputCtrl.text.trim().toUpperCase() == 'KHELO500') {
                                    setState(() => _referralClaimed = true);
                                    await _addCoins(500);
                                    final uid = FirebaseAuth.instance.currentUser?.uid;
                                    if (uid != null) {
                                      await FirebaseFirestore.instance.collection('users').doc(uid).set({'referralClaimed': true}, SetOptions(merge: true));
                                    }
                                  }
                                },
                                child: const Text('Apply Referral Code (+500 Coins)'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      child: const Text('Logout Account'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.gamepad), label: 'Games'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: 'Withdraw'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  void _playTtt(int idx) {
    setState(() => _tttBoard[idx] = 'X');
    if (_checkTttWin('X')) {
      setState(() {
        _tttOver = true;
        _tttStatus = 'You Won! Ad completed for +30 Coins.';
      });
      _showRewardedAd(() => _addCoins(30));
      return;
    }
    final empty = [for (int i = 0; i < 9; i++) if (_tttBoard[i].isEmpty) i];
    if (empty.isEmpty) {
      setState(() {
        _tttOver = true;
        _tttStatus = 'Match Draw! No coins awarded.';
      });
      return;
    }
    final bot = empty[Random().nextInt(empty.length)];
    setState(() => _tttBoard[bot] = 'O');
    if (_checkTttWin('O')) {
      setState(() {
        _tttOver = true;
        _tttStatus = 'You Lost! No coins awarded.';
      });
    }
  }

  bool _checkTttWin(String s) {
    const lines = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8],
      [0, 3, 6], [1, 4, 7], [2, 5, 8],
      [0, 4, 8], [2, 4, 6]
    ];
    return lines.any((l) => _tttBoard[l[0]] == s && _tttBoard[l[1]] == s && _tttBoard[l[2]] == s);
  }
}

class _WheelPainter extends CustomPainter {
  final List<int> values;
  final List<Color> colors;
  _WheelPainter(this.values, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sweep = (2 * pi) / values.length;
    final paint = Paint()..style = PaintingStyle.fill;
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white
      ..strokeWidth = 2.5;

    for (int i = 0; i < values.length; i++) {
      final start = i * sweep - pi / 2;
      paint.color = colors[i % colors.length];
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, true, paint);
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, true, border);

      final textAngle = start + sweep / 2;
      final tx = center.dx + (radius * 0.65) * cos(textAngle);
      final ty = center.dy + (radius * 0.65) * sin(textAngle);
      final tp = TextPainter(
        text: TextSpan(text: '${values[i]}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(tx - tp.width / 2, ty - tp.height / 2));
    }
    canvas.drawCircle(center, 16, Paint()..color = const Color(0xFF0F172A));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
