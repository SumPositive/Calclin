//
//  IdleBanner.swift
//  Calclin
//
//  しばらく操作が無いときだけ、主画面の上端にバナー広告を差し込む。
//  - 最後に画面を触ってから IDLE_BANNER_DELAY 秒で上端から下りてくる
//    （同時に、入力行を残してロールだけをフェードアウトする）
//  - バナーの外を触ったら、すぐにスライドアウト
//  - 引っ込めたら、また操作が無くなるのを待つ
//  主画面には常設のバナーを置く場所が無いので、使っていない間だけ出す
//  ロールのボタンの上に重ねると誤タップを招くので、出ている間はロールごと消して押せなくする
//

import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// 操作が無くなってからバナーを出すまでの秒数
let IDLE_BANNER_DELAY: Double = 20
/// 広告を受け取れなかったとき、次に試すまでの秒数（通信不可などで何度も要求しない）
let IDLE_BANNER_RETRY_DELAY: Double = 60
/// 広告の返事を待つ上限の秒数。返事が無ければ受け取れなかったものとして扱う
let IDLE_BANNER_LOAD_TIMEOUT: Double = 15
/// 出た直後はバナーへのタップを受け付けない秒数。
/// 戻ってきた指がちょうど出てきたバナーに当たる誤タップを防ぐ
/// （誤タップが多いと広告配信を止められる。Vitalin の教訓）
let IDLE_BANNER_TAP_GUARD: Double = 1.0

// MARK: - 画面のどこを触っても知らせる

/// タッチを横取りせずに「触った」ことと位置だけを知らせるジェスチャー。
/// ウインドウに付けるので、シートや吹き出しの上のタッチも拾える
private final class TouchObserverGesture: UIGestureRecognizer, UIGestureRecognizerDelegate {
    /// 触った位置（ウインドウ座標＝SwiftUI の .global とそろう）
    var onTouch: ((CGPoint) -> Void)?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        // 本来のタッチ処理（ボタン・スクロールなど）を一切邪魔しない
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if let touch = touches.first {
            onTouch?(touch.location(in: nil))
        }
        // 自分は何も認識しない（他のジェスチャーを妨げない）
        state = .failed
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
}

/// TouchObserverGesture をウインドウへ取り付けるための見えない View
private struct TouchObserverInstaller: UIViewRepresentable {
    let onTouch: (CGPoint) -> Void

    func makeUIView(context: Context) -> InstallerView {
        let view = InstallerView()
        view.isUserInteractionEnabled = false
        view.onTouch = onTouch
        return view
    }

    func updateUIView(_ uiView: InstallerView, context: Context) {
        uiView.onTouch = onTouch
    }

    final class InstallerView: UIView {
        var onTouch: ((CGPoint) -> Void)? {
            didSet { gesture.onTouch = onTouch }
        }
        private let gesture = TouchObserverGesture(target: nil, action: nil)

        override func didMoveToWindow() {
            super.didMoveToWindow()
            // ウインドウが付いたら、そのウインドウ全体のタッチを見張る
            gesture.view?.removeGestureRecognizer(gesture)
            window?.addGestureRecognizer(gesture)
        }
    }
}

// MARK: - 放置時のバナー

/// 放置時バナーの状態とタイマー
/// - 出ている間は入力行を残してロールだけをフェードアウトし、そこにバナーを出す
@MainActor
final class IdleBannerState: ObservableObject {
    /// 広告を要求中か（まだ見せていない）
    /// - 受け取れたときだけ見せてロールを隠す。受け取れなければロールはそのまま
    @Published private(set) var isRequesting = false
    /// 広告を受け取って見せているか（このときだけロールを隠す）
    @Published private(set) var isVisible = false
    /// 出た直後の誤タップ防止中か
    @Published private(set) var isTapGuarded = false
    /// バナーの位置（.global）。バナーの上のタッチは「外を触った」に数えない
    var bannerFrame: CGRect = .zero
    /// true の間は出さない（シートやポップアップで作業中など）
    var isSuspended = false {
        didSet {
            guard oldValue != isSuspended else { return }
            if isSuspended {
                // 作業を始めたら、出ていれば引っ込める
                hide()
            } else {
                restartIdleTimer()
            }
        }
    }

    /// 操作が無くなるのを待つ
    private var idleTask: Task<Void, Never>?
    /// 広告の返事を待つ（来なければ受け取れなかったものとして扱う）
    private var loadTimeoutTask: Task<Void, Never>?

    /// 画面のどこかを触った
    func handleTouch(at point: CGPoint) {
        if isVisible {
            // バナーの上のタッチは広告側に任せ、引っ込めるきっかけにしない
            guard !bannerFrame.contains(point) else { return }
            // 外を触ったら、すぐに引っ込める（使い始めた人を待たせない）
            hide()
        } else {
            // 要求中に触ったら要求をやめる（受け取れても出さない）
            cancelRequest()
            // 触るたびに、操作が無くなるまでの待ちを数え直す
            restartIdleTimer()
        }
    }

    /// 操作が無くなるのを待ち直す
    func restartIdleTimer(after delay: Double = IDLE_BANNER_DELAY) {
        idleTask?.cancel()
        idleTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.show()
        }
    }

    /// 広告を要求する。この時点ではまだ何も見せない（ロールもそのまま）
    private func show() {
        // スクリーンショット撮影中や、作業中（シートなど）は出さない
        guard !SnapshotSupport.isRunningSnapshot, !isSuspended,
              !isVisible, !isRequesting else { return }
        isRequesting = true
        // 返事が来ないまま待ち続けないよう、上限を決めておく
        loadTimeoutTask?.cancel()
        loadTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(IDLE_BANNER_LOAD_TIMEOUT))
            guard !Task.isCancelled else { return }
            self?.adDidFail()
        }
    }

    /// 広告を受け取れた。ここで初めて見せて、ロールを隠す
    func adDidLoad() {
        guard isRequesting else { return }
        isRequesting = false
        loadTimeoutTask?.cancel()
        isTapGuarded = true
        // バナーが下りてくるのと同時にロールがフェードアウトする
        withAnimation(.easeOut(duration: 0.35)) {
            isVisible = true
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(IDLE_BANNER_TAP_GUARD))
            self?.isTapGuarded = false
        }
    }

    /// 広告を受け取れなかった（通信不可・在庫なし・時間切れ）。
    /// ロールは隠していないので、そのまま。少し間を空けてから、また試す
    func adDidFail() {
        guard isRequesting else { return }
        cancelRequest()
        if !isSuspended { restartIdleTimer(after: IDLE_BANNER_RETRY_DELAY) }
    }

    /// 要求をやめる（見せる前なので画面は変わらない）
    private func cancelRequest() {
        isRequesting = false
        loadTimeoutTask?.cancel()
        loadTimeoutTask = nil
    }

    private func hide() {
        cancelRequest()
        if isVisible {
            // バナーが上がるのと同時にロールがフェードインする
            withAnimation(.easeIn(duration: 0.3)) {
                isVisible = false
            }
        }
        bannerFrame = .zero
        // 引っ込めたら、また操作が無くなるのを待つ
        if !isSuspended { restartIdleTimer() }
    }
}

/// 放置時バナーの帯（消えたロールの上端に出す）
struct IdleBannerBar: View {
    @ObservedObject var state: IdleBannerState
    /// 広告に使える幅と高さ（消えたロールの範囲から余白を引いたもの）
    let availableSize: CGSize
    /// 受け取った広告の高さ（受け取るまでは帯状バナーの高さで場所を取っておく）
    @State private var adHeight: CGFloat = 50

    var body: some View {
        // インライン アダプティブ：空いている高さを上限に、Google が大きさを選ぶ
        // （ロールが低ければ帯状、高ければレクタングル級）
        InlineAdaptiveBannerView(adUnitID: ADMOB_IDLE_BANNER_UnitID,
                                 width: availableSize.width,
                                 maxHeight: availableSize.height,
                                 onHeightChange: { height in
            guard 0 < height else { return }
            adHeight = height
            // 受け取れたので見せる（ここで初めてロールを隠す）
            state.adDidLoad()
        },
                                 onFail: {
            // 受け取れなければ見せないまま引き下げる（ロールは隠さない）
            state.adDidFail()
        })
            .frame(width: availableSize.width, height: adHeight)
            // 出た直後は透明な覆いでタップを止める（誤タップ防止）
            .overlay {
                if state.isTapGuarded {
                    Color.black.opacity(0.001)
                }
            }
            // 誤タップを避けるため、バナーの上下は広めに空ける
            .padding(.vertical, IDLE_BANNER_VERTICAL_PADDING)
            .frame(maxWidth: .infinity)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                state.bannerFrame = frame
            }
    }
}

/// バナーの上下の余白
let IDLE_BANNER_VERTICAL_PADDING: CGFloat = 10
/// バナーの左右の余白（ロールの枠から離す）
let IDLE_BANNER_HORIZONTAL_PADDING: CGFloat = 8

/// 放置時のバナー広告が出ていて、ロールを隠しているか
/// - ロール（履歴）とその上のヘッダだけを消し、入力行は残す
private struct RollHiddenForAdKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    // ＃@Entry マクロはこのプロジェクトでは展開されず型推論エラーになるので、従来の書き方にする
    var isRollHiddenForAd: Bool {
        get { self[RollHiddenForAdKey.self] }
        set { self[RollHiddenForAdKey.self] = newValue }
    }
}

/// 画面のタッチとアプリの出入りを放置時バナーへ伝える
private struct IdleBannerModifier: ViewModifier {
    @ObservedObject var state: IdleBannerState
    let isSuspended: Bool

    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .background(TouchObserverInstaller { point in state.handleTouch(at: point) })
            .onAppear {
                state.isSuspended = isSuspended
                state.restartIdleTimer()
            }
            .onChange(of: isSuspended) { _, suspended in
                state.isSuspended = suspended
            }
            .onChange(of: scenePhase) { _, phase in
                // アプリへ戻ってきたら、そこから数え直す（すぐに出さない）
                if phase == .active, !state.isVisible { state.restartIdleTimer() }
            }
    }
}

extension View {
    /// 操作が無いときだけ、ロールの上にバナー広告を出す（タッチの見張りとタイマー）
    func idleBanner(_ state: IdleBannerState, isSuspended: Bool) -> some View {
        modifier(IdleBannerModifier(state: state, isSuspended: isSuspended))
    }
}

// MARK: - 広告の地

/// 広告の載る面の地。和紙のような短い繊維を散らした、ざらっとした紙（Nenrin と同じ作り）
/// - 地を一段沈めて、広告がアプリの画面の一部に見えないようにする
struct AdAreaBackground: View {
    let colorScheme: ColorScheme

    /// 紙の地色。生成りを一段沈めた色。ダークは墨を含んだ濃い紙にする
    private var paperColor: Color {
        let (r, g, b) = colorScheme == .dark
            ? (0.16, 0.15, 0.13)
            : (0.98, 0.96, 0.92)
        // 沈める量。ダークは元が暗いので浅く、ライトは影として分かる程度に落とす
        let amount = colorScheme == .dark ? 0.35 : 0.055
        return Color(red: r * (1 - amount), green: g * (1 - amount), blue: b * (1 - amount))
    }

    /// 繊維の色。地より少しだけ濃くして、透かしたときの繊維に見せる
    private var fiberColor: Color {
        colorScheme == .dark
            ? Color(red: 0.35, green: 0.33, blue: 0.29)
            : Color(red: 0.80, green: 0.75, blue: 0.66)
    }

    var body: some View {
        Rectangle()
            .fill(paperColor)
            .overlay {
                Canvas { context, size in
                    drawFibers(in: context, size: size)
                }
            }
    }

    /// 短い繊維を敷き詰める。長さと向きをばらつかせると紙らしくなる
    private func drawFibers(in context: GraphicsContext, size: CGSize) {
        // 同じ模様を再現するため、毎回同じ種から乱数を作る（再描画で模様が動かない）
        var generator = AdSeededGenerator(seed: 20261010)
        // 面積に比例させ、広さが変わっても密度をそろえる
        let count = Int(size.width * size.height / 90)

        for _ in 0..<count {
            let x = Double.random(in: 0...size.width, using: &generator)
            let y = Double.random(in: 0...size.height, using: &generator)
            let length = Double.random(in: 3...11, using: &generator)
            // 和紙の繊維は漉くときの流れでやや横向きに寝る
            let angle = Double.random(in: -0.5...0.5, using: &generator)
            let opacity = Double.random(in: 0.10...0.30, using: &generator)

            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x + cos(angle) * length, y: y + sin(angle) * length))

            context.stroke(
                path,
                with: .color(fiberColor.opacity(opacity)),
                lineWidth: Double.random(in: 0.4...0.9, using: &generator)
            )
        }
    }
}

/// 種を決めて同じ乱数列を作る（SplitMix64）
private struct AdSeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // 0 は次の値も 0 になるため、種が 0 でも進む値にずらす
        state = seed &+ 0x9E3779B97F4A7C15
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - 広告が出たら吹き出しを閉じる

/// 放置時の広告が出たときに、開いている吹き出しを閉じるための見張り
/// - 吹き出しの開閉はそれぞれの View が持っているので、出た合図（環境値）を見て各自で閉じる
private struct IdleAdShownModifier: ViewModifier {
    @Environment(\.isRollHiddenForAd) private var isRollHiddenForAd
    let action: () -> Void

    func body(content: Content) -> some View {
        content.onChange(of: isRollHiddenForAd) { _, hidden in
            if hidden { action() }
        }
    }
}

extension View {
    /// 放置時の広告が出たときに action を呼ぶ（吹き出しを閉じるなど）
    func onIdleAdShown(_ action: @escaping () -> Void) -> some View {
        modifier(IdleAdShownModifier(action: action))
    }
}
