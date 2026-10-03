import 'package:flutter/material.dart';

/// Pengendali animasi goyang — panggil [goyang] saat input salah.
///
/// Dipakai bersama [PembungkusGoyang]. Animasi memakai [Transform.translate]
/// (GPU-safe, bukan perubahan layout).
class PengendaliGoyang extends ChangeNotifier {
  void goyang() => notifyListeners();
}

/// Membungkus widget agar bisa bergoyang ke kiri-kanan saat [pengendali]
/// dipicu — untuk feedback PIN / kata sandi salah.
class PembungkusGoyang extends StatefulWidget {
  const PembungkusGoyang({
    super.key,
    required this.pengendali,
    required this.child,
  });

  final PengendaliGoyang pengendali;
  final Widget child;

  @override
  State<PembungkusGoyang> createState() => _PembungkusGoyangState();
}

class _PembungkusGoyangState extends State<PembungkusGoyang>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kontrol;
  late final Animation<double> _animasi;

  @override
  void initState() {
    super.initState();
    _kontrol = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _animasi = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -12), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12, end: 10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10, end: -6), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6, end: 4), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 4, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _kontrol, curve: Curves.easeInOut));
    widget.pengendali.addListener(_mainkan);
  }

  void _mainkan() {
    _kontrol.reset();
    _kontrol.forward();
  }

  @override
  void dispose() {
    widget.pengendali.removeListener(_mainkan);
    _kontrol.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animasi,
      builder: (context, child) => Transform.translate(
        offset: Offset(_animasi.value, 0),
        child: child,
      ),
      child: widget.child,
    );
  }
}
