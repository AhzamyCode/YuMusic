/// Sleep timer: musik dikecilkan perlahan lalu berhenti.
class SleepTimerState {
  const SleepTimerState.at(DateTime this.endsAt) : endOfTrack = false;
  const SleepTimerState.endOfTrack()
      : endsAt = null,
        endOfTrack = true;

  /// Waktu musik berhenti; null bila berhenti di akhir lagu.
  final DateTime? endsAt;
  final bool endOfTrack;
}

/// Lama volume diturunkan sebelum musik berhenti.
const sleepFade = Duration(seconds: 30);

/// Volume 0..1 saat sisa waktu [left]: penuh, lalu turun lurus selama [fade]
/// terakhir.
double sleepVolume(Duration left, [Duration fade = sleepFade]) {
  if (left >= fade) return 1;
  if (left <= Duration.zero) return 0;
  return left.inMilliseconds / fade.inMilliseconds;
}

/// Sebuah putaran dihitung setelah lagu didengar 30 detik, atau separuhnya
/// untuk lagu yang lebih pendek dari semenit.
Duration playCountThreshold(Duration? length) {
  const usual = Duration(seconds: 30);
  if (length == null || length <= Duration.zero) return usual;
  final half = length ~/ 2;
  return half < usual ? half : usual;
}
