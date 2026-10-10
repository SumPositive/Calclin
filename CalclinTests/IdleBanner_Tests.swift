// IdleBanner_Tests.swift
// 放置時のバナー広告の状態の移り変わりのテスト
//
// ＃待ち時間は短くして（数十ミリ秒）、実際のタイマーで動きを確かめる

import Foundation
import Testing

@testable import Calclin

/// 待ち時間を短くした状態
/// ＃待つ側（wait）は満了の数倍の余裕を取り、遅い環境でも結果が揺れないようにする
@MainActor
private func makeState(loadTimeout: Double = 5, retryDelay: Double = 0.05) -> IdleBannerState {
    IdleBannerState(timing: .init(idleDelay: 0.05,
                                  retryDelay: retryDelay,
                                  loadTimeout: loadTimeout,
                                  tapGuard: 0.05))
}

/// タイマーが満了するまで待つ
private func wait(_ seconds: Double = 0.3) async throws {
    try await Task.sleep(for: .seconds(seconds))
}

@Suite("放置時のバナー広告", .serialized)
@MainActor
struct IdleBannerStateTests {

    @Test("操作が無いと、まず広告を要求する（まだ見せない）")
    func requestsAfterIdle() async throws {
        let state = makeState()
        state.restartIdleTimer()
        try await wait()
        #expect(state.isRequesting)
        #expect(state.isVisible == false)
    }

    @Test("広告を受け取れたら見せる")
    func showsWhenLoaded() async throws {
        let state = makeState()
        state.restartIdleTimer()
        try await wait()
        state.adDidLoad()
        #expect(state.isVisible)
        #expect(state.isRequesting == false)
        // 出た直後は誤タップ防止中
        #expect(state.isTapGuarded)
        try await wait()
        #expect(state.isTapGuarded == false)
    }

    @Test("広告を受け取れなければ見せず、間を空けてまた要求する")
    func retriesAfterFailure() async throws {
        let state = makeState()
        state.restartIdleTimer()
        try await wait()
        state.adDidFail()
        #expect(state.isRequesting == false)
        #expect(state.isVisible == false)
        try await wait()
        #expect(state.isRequesting)
    }

    @Test("返事が来なければ時間切れで要求をやめる")
    func timesOutWithoutResponse() async throws {
        // 時間切れは短く、再要求は遠くにして、時間切れ直後の状態を確かめる
        let state = makeState(loadTimeout: 0.3, retryDelay: 60)
        state.restartIdleTimer()
        try await wait(0.15)
        #expect(state.isRequesting)
        try await wait(0.6)
        #expect(state.isRequesting == false)
        #expect(state.isVisible == false)
    }

    @Test("要求していないときの受信の知らせは無視する")
    func ignoresLoadWithoutRequest() {
        let state = makeState()
        state.adDidLoad()
        #expect(state.isVisible == false)
    }

    @Test("見せている間に外を触ったら、すぐ引っ込める")
    func hidesOnTouchOutside() async throws {
        let state = makeState()
        state.restartIdleTimer()
        try await wait()
        state.adDidLoad()
        state.bannerFrame = CGRect(x: 0, y: 0, width: 320, height: 100)
        state.handleTouch(at: CGPoint(x: 10, y: 500))
        #expect(state.isVisible == false)
    }

    @Test("広告の上を触っても引っ込めない")
    func keepsOnTouchInside() async throws {
        let state = makeState()
        state.restartIdleTimer()
        try await wait()
        state.adDidLoad()
        state.bannerFrame = CGRect(x: 0, y: 0, width: 320, height: 100)
        state.handleTouch(at: CGPoint(x: 10, y: 50))
        #expect(state.isVisible)
    }

    @Test("要求中に触ったら要求をやめ、後から届いても見せない")
    func cancelsRequestOnTouch() async throws {
        let state = makeState()
        state.restartIdleTimer()
        try await wait()
        #expect(state.isRequesting)
        state.handleTouch(at: CGPoint(x: 10, y: 10))
        #expect(state.isRequesting == false)
        state.adDidLoad()
        #expect(state.isVisible == false)
    }

    @Test("作業中（シートなど）は要求しない")
    func doesNotRequestWhileSuspended() async throws {
        let state = makeState()
        state.isSuspended = true
        state.restartIdleTimer()
        try await wait()
        #expect(state.isRequesting == false)
        #expect(state.isVisible == false)
    }

    @Test("見せている間に作業を始めたら引っ込める")
    func hidesWhenSuspended() async throws {
        let state = makeState()
        state.restartIdleTimer()
        try await wait()
        state.adDidLoad()
        state.isSuspended = true
        #expect(state.isVisible == false)
    }

    @Test("アプリを離れている間は数えない")
    func pausesWhileInactive() async throws {
        let state = makeState()
        state.restartIdleTimer()
        state.pauseWhileInactive()
        try await wait()
        #expect(state.isRequesting == false)
        #expect(state.isVisible == false)
    }

    @Test("アプリを離れたら、見せている広告も引っ込める")
    func hidesWhenInactive() async throws {
        let state = makeState()
        state.restartIdleTimer()
        try await wait()
        state.adDidLoad()
        state.pauseWhileInactive()
        #expect(state.isVisible == false)
        // 戻るまで再要求しない
        try await wait()
        #expect(state.isRequesting == false)
    }
}
