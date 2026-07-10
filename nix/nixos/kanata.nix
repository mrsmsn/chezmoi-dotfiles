{ ... }:

# 内蔵キーボードのキーリマップ (kanata)。
#
# HomeRowMods (CSAG) を ZMK キーボード (zmk_config_CLine46) の hm behavior と
# 同一パラメータで再現する: flavor=balanced (kanata の tap-hold-release)、
# tapping-term-ms=200、quick-tap-ms=175 (tap-hold の第1引数 tap-repress-timeout)。
# xremap では balanced flavor (他キーの press+release で hold 確定) と quick-tap
# が実装できないため kanata へ全面移行した。
{
  services.kanata = {
    enable = true;
    keyboards.internal = {
      # 内蔵キーボードだけを grab する。CLine46 (ZMK キーボード) を接続した
      # ときにファームウェア側 HRM と二重適用になるのを避けるため、全キーボード
      # 一律適用にはしない。パスは実機の `ls -l /dev/input/by-path/ | grep kbd`
      # で確認したもの。
      devices = [ "/dev/input/by-path/platform-i8042-serio-0-event-kbd" ];
      # defsrc に無いキーはそのまま素通しする。
      extraDefCfg = "process-unmapped-keys yes";
      config = ''
        ;; KEY_HANGEUL/KEY_HANJA は kanata の Linux ターゲットに builtin 名が
        ;; 無いため evdev コードで定義する (henk/katakanahiragana/ro は builtin)。
        (deflocalkeys-linux
          hngl 122
          hanj 123
        )

        (defsrc
          caps a s d f j k l ; lalt henk katakanahiragana ro
        )

        (defalias
          ;; HRM (CSAG): 単押し=文字 / 長押し=modifier。
          ;; tap-hold-release = ZMK の flavor "balanced" (tapping-term 内に他キー
          ;; の press+release が完了したときだけ hold 判定)。
          ;; 第1引数 175 = quick-tap-ms (タップ直後 175ms 以内の再押下は強制 tap
          ;; = キーリピート用)、第2引数 200 = tapping-term-ms。
          a (tap-hold-release 175 200 a lctl)
          s (tap-hold-release 175 200 s lsft)
          d (tap-hold-release 175 200 d lalt)
          f (tap-hold-release 175 200 f lmet)
          j (tap-hold-release 175 200 j rmet)
          k (tap-hold-release 175 200 k ralt)
          l (tap-hold-release 175 200 l rsft)
          scln (tap-hold-release 175 200 ; rctl)

          ;; 左右 Alt を dual-role 化して macOS の英数/かな相当を作る:
          ;; 押しっぱなしは従来通り Alt(修飾キー)、単押しのときだけ IME 切替キー
          ;; を送出する。
          ;;   左Alt 単押し -> Hangul_Hanja (fcitx5 の Deactivate = 英数/us 直接入力)
          ;;   右Alt 単押し -> Hangul       (fcitx5 の Activate   = mozc/かな)
          ;; あえて Henkan/Muhenkan ではなく Hangul 系キーシムを使う: Mozc は既定
          ;; キーマップでこれらを束縛しない (Korean 用) ため Mozc に消費されず、
          ;; fcitx5 の Activate/Deactivate が競合なく発火する。Henkan/Muhenkan だと
          ;; Mozc がカナ種切替として先に食ってしまい fcitx5 の切替が効かない。
          ;; ショートカット (Alt+Tab 等) の即応性を保つため、こちらは
          ;; tap-hold-press (hold-preferred: 他キーの press で即 hold 確定)。
          lalt (tap-hold-press 175 200 hanj lalt)
          henk (tap-hold-press 175 200 hngl ralt)
        )

        ;; 内蔵キーボードの右側 3 キーは JIS キーのイベントコードを吐くので
        ;; 本来のキーへ戻す (右Alt=Convert/HENKAN, 右App=KanaMode/KATAKANAHIRAGANA,
        ;; 右Ctrl=IntlRo/RO)。右App は右Super に割り当てる。
        (deflayer default
          lctl @a @s @d @f @j @k @l @scln @lalt @henk rmet rctl
        )
      '';
    };
  };
}
