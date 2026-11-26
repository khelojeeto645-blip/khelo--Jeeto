import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:share_plus/share_plus.dart';
import '../config/app_config.dart';

class HomeScreen extends StatefulWidget {
  final bool darkMode;
  final ValueChanged<bool> onThemeChanged;
  const HomeScreen({super.key, required this.darkMode, required this.onThemeChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  int _coins = 0;
  int _adsToday = 0;
  int _quizCorrect = 0;
  int _quizWrong = 0;
  int _quizIdx = 0;
  String _myReferCode = 'KJ-USER99';
  RewardedAd? _rewardedAd;

  final List<int> _spinValues = [10, 20, 30, 40, 50];
  final List<String> _tttBoard = List.filled(9, '');
  bool _tttOver = false;
  String _tttStatus = '';

  final _upiCtrl = TextEditingController();
  final _referInputCtrl = TextEditingController();
  int _selectedWithdrawAmt = 10;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadRewardedAd();
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists && mounted) {
      setState(() {
        _coins = (doc.data()?['coins'] ?? 0) as int;
        _adsToday = (doc.data()?['adsWatchedToday'] ?? 0) as int;
        _myReferCode = (doc.data()?['myReferCode'] ?? 'KJ-USER99') as String;
      });
    }
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ad loading, please try again in a second.')));
      return;
    }
    _rewardedAd!.show(onUserEarnedReward: (_, __) async {
      setState(() => _adsToday += 1);
      onReward();
      _loadRewardedAd();
    });
  }

  Future<void> _addCoins(int amount) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _coins += amount);
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'coins': FieldValue.increment(amount),
      'adsWatchedToday': _adsToday,
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final rupees = (_coins / AppConfig.coinsPerRupee).toStringAsFixed(2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('KHELO & JEETO', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(label: Text('$_coins Coins (₹$rupees)')),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          // TAB 0: GAMES
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  title: const Text('Daily Spin & Win (10–50 Coins)', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Ads Today: $_adsToday / ${AppConfig.maxDailyAds}'),
                  trailing: FilledButton(
                    onPressed: () {
                      final won = _spinValues[Random().nextInt(_spinValues.length)];
                      _showRewardedAd(() => _addCoins(won));
                    },
                    child: const Text('Spin'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tic-Tac-Toe (Medium Mode) — Win: +30 Coins', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 9,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8),
                        itemBuilder: (_, i) => OutlinedButton(
                          onPressed: _tttOver || _tttBoard[i].isNotEmpty ? null : () => _playTtt(i),
                          child: Text(_tttBoard[i], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      if (_tttStatus.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(_tttStatus, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                      if (_tttOver)
                        TextButton(
                          onPressed: () => setState(() {
                            _tttBoard.fillRange(0, 9, '');
                            _tttOver = false;
                            _tttStatus = '';
                          }),
                          child: const Text('Play Again'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quiz (Correct: $_quizCorrect | Wrong: $_quizWrong)', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('In which year did India win its first Cricket World Cup?'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: ['1979', '1983', '1987', '2007'].map((opt) => OutlinedButton(
                          onPressed: () {
                            if (opt == '1983') {
                              setState(() => _quizCorrect++);
                              _showRewardedAd(() => _addCoins(25));
                            } else {
                              setState(() => _quizWrong++);
                            }
                          },
                          child: Text(opt),
                        )).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // TAB 1: UPI WITHDRAW
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
                  child: Text('Withdraw ₹$_selectedWithdrawAmt via UPI'),
                ),
              ],
            ),
          ),

          // TAB 2: PAYMENT HISTORY
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('withdrawals')
                .where('uid', isEqualTo: user?.uid)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;
              if (docs.isEmpty) return const Center(child: Text('No UPI payouts yet.'));
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  return Card(
                    child: ListTile(
                      title: Text('UPI: ${d['upiId']}'),
                      subtitle: Text('Status: ${d['status']}'),
                      trailing: Text('₹${d['amountInr']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  );
                },
              );
            },
          ),

          // TAB 3: SETTINGS
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                leading: const Icon(Icons.mail),
                title: Text(user?.email ?? 'Not logged in'),
                subtitle: const Text('Verified Gmail Account'),
              ),
              SwitchListTile(
                title: const Text('Dark Mode (Eye Comfort)'),
                value: widget.darkMode,
                onChanged: widget.onThemeChanged,
              ),
              const Divider(),
              ListTile(
                title: Text('Your Referral Code: $_myReferCode'),
                subtitle: Text('${AppConfig.downloadBaseUrl}$_myReferCode'),
                trailing: IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () => Share.share('Download Khelo & Jeeto and use code $_myReferCode for 500 Coins: ${AppConfig.downloadBaseUrl}$_myReferCode'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(controller: _referInputCtrl, decoration: const InputDecoration(labelText: 'Enter Friend Referral Code', border: OutlineInputBorder())),
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
        _tttStatus = 'You Won! Watch Ad for +30 Coins.';
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
