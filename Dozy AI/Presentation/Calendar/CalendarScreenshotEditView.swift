//
//  CalendarScreenshotEditView.swift
//  Dozy AI
//
//  iOS 기본 스크린샷 마크업 같은 편집 화면.
//  지원: 펜슬킷 마크업 · 90° 회전 · 자르기 · 공유 · 저장.
//

import SwiftUI
import PencilKit
import UIKit
import Combine

struct CalendarScreenshotEditView: View {

    /// 캡쳐된 원본 캘린더 이미지.
    let image: UIImage
    /// 저장 버튼 — caller 가 합성된 이미지를 받아 PHPhotoLibrary 에 쓰고 dismiss.
    let onSave: (UIImage) -> Void
    /// 취소 버튼 — caller 가 dismiss 만.
    let onCancel: () -> Void

    /// 회전/자르기로 변형되는 현재 작업 이미지. 저장/공유 합성은 이 위에서 일어남.
    @State private var currentImage: UIImage
    @State private var drawing = PKDrawing()
    @State private var canvasView: PKCanvasView?
    /// PKToolPicker 는 화면당 1개만 유지해야 toolbar 깜빡임 없음.
    @State private var toolPicker = PKToolPicker()
    /// 공유 시트 식별자 — nil 이면 시트 닫힘. UIImage 와 Bool 을 따로 두면 첫 탭 race 로 빈 시트가
    /// 뜨는 SwiftUI 버그가 있어 단일 옵셔널 item 으로 묶음.
    @State private var shareItem: ShareItem?
    @State private var showCropView = false
    /// 회전 버튼 탭 → 0.3s 동안 rotationEffect 로 시각 회전 후 비트맵 swap.
    @State private var displayRotation: Angle = .zero
    /// 애니메이션 중 추가 탭 무시용.
    @State private var isRotating = false
    /// 비율 조절 슬라이더 값. 합성 시 출력 사이즈에 곱해진다. 회전·자르기 시점에 1.0 리셋.
    @State private var zoomScale: CGFloat = 1.0
    private let minZoom: CGFloat = 0.25
    private let maxZoom: CGFloat = 3.0
    /// 되돌리기 스택 — 회전/자르기/줌/펜 스트로크 직전 상태 스냅샷. 일정 시간 지나면 만료되어 prune.
    @State private var undoStack: [EditSnapshot] = []
    /// 가장 최근 commit 된 펜 drawing — N번째 stroke 도 정확히 그 전 상태로 push 하기 위한 트래커.
    /// @State `drawing` 은 SwiftUI body 재평가 타이밍 때문에 stroke begin 시 stale 할 수 있어 별도 보관.
    @State private var lastCommittedDrawing = PKDrawing()
    /// 매초 prune 트리거용 현재 시각 (1초 단위로 갱신).
    @State private var nowTick = Date()
    /// snapshot 유효 시간(초). 이 시간 지나면 stack 에서 제거되고 undo 비활성화.
    private let undoTTL: TimeInterval = 120
    /// PencilKit 캔버스의 .id 키. undo/회전/자르기 시 갱신해 canvas 자체를 재생성 → 내부 stroke 렌더
    /// 캐시 잔상 원천 차단. 새 canvas 는 initialDrawing(현재 drawing State) 로 깨끗이 시작.
    @State private var canvasReloadID = UUID()
    /// canvasArea GeometryReader 가 산정한 displayed 사이즈. PencilKit 캔버스 frame 과 동일하며
    /// composeImage 에서 PKDrawing 좌표계 → 출력 좌표계 매핑에 사용.
    @State private var displayedSize: CGSize = .zero
    @Environment(\.colorScheme) private var colorScheme

    init(image: UIImage, onSave: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
        self.image = image
        self.onSave = onSave
        self.onCancel = onCancel
        _currentImage = State(initialValue: image)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            ratioControlBar
            Divider()
            canvasArea
        }
        .background(Color(.systemBackground))
        .fullScreenCover(
            isPresented: $showCropView,
            onDismiss: { showToolPicker() }
        ) {
            ScreenshotCropView(image: currentImage) { cropped in
                if let cropped {
                    pushUndoSnapshot()
                    applyImage(cropped)
                }
                showCropView = false
            }
        }
        .sheet(
            item: $shareItem,
            onDismiss: { showToolPicker() }
        ) { item in
            ShareSheet(activityItems: [item.image])
        }
        // 1초마다 만료 스냅샷 제거 → TTL 지나면 undo 자연스럽게 비활성화.
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
            nowTick = date
            pruneExpiredSnapshots()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 16) {
            Button("취소", role: .cancel) { onCancel() }
                .foregroundStyle(.primary)

            Spacer()

            // 액션 그룹: 되돌리기 / 회전CCW / 회전CW / 자르기 / 공유.
            Button { performUndo() } label: {
                Image(systemName: "arrow.uturn.backward").font(.title3)
            }
            .disabled(!canUndo)
            .accessibilityLabel("되돌리기")

            Button { rotate(byDegrees: -90) } label: {
                Image(systemName: "rotate.left").font(.title3)
            }
            .accessibilityLabel("왼쪽으로 회전")

            Button { rotate(byDegrees: 90) } label: {
                Image(systemName: "rotate.right").font(.title3)
            }
            .accessibilityLabel("오른쪽으로 회전")

            Button {
                hideToolPicker()
                showCropView = true
            } label: {
                Image(systemName: "crop").font(.title3)
            }
            .accessibilityLabel("자르기")

            Button {
                hideToolPicker()
                shareItem = ShareItem(image: composeImage())
            } label: {
                Image(systemName: "square.and.arrow.up").font(.title3)
            }
            .accessibilityLabel("공유")

            Spacer()

            Button("저장") {
                onSave(composeImage())
            }
            .fontWeight(.semibold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    // MARK: - Ratio Control Bar

    /// 출력 이미지의 비율(스케일) 슬라이더. 미리보기에 실시간 반영되고 저장 시 그대로 합성됨.
    private var ratioControlBar: some View {
        HStack(spacing: 10) {
            Button {
                if zoomScale != 1.0 { pushUndoSnapshot() }
                zoomScale = 1.0
            } label: {
                Text("100%")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.secondary.opacity(0.12)))
            }
            .buttonStyle(.plain)

            Image(systemName: "minus.magnifyingglass")
                .foregroundStyle(.secondary)

            Slider(
                value: $zoomScale,
                in: minZoom...maxZoom,
                step: 0.05,
                onEditingChanged: { editing in
                    if editing { pushUndoSnapshot() }
                }
            )

            Image(systemName: "plus.magnifyingglass")
                .foregroundStyle(.secondary)

            Text("\(Int((zoomScale * 100).rounded()))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.primary)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - Canvas Area

    private var canvasArea: some View {
        GeometryReader { geo in
            ZStack {
                (colorScheme == .dark ? Color.black : Color(.systemGray6))
                    .ignoresSafeArea()

                let displayed = displaySize(for: currentImage.size, in: geo.size)
                ZStack {
                    // 배경 — 전체 캔버스 영역. 외부 canvasArea 배경과 동일 톤이라 zoom 축소 시 이질감 없음.
                    canvasMarginColor
                        .frame(width: displayed.width, height: displayed.height)

                    // 이미지: zoomScale 만 이 frame 에 적용 → 캔버스 내부에서 중앙으로 축소/확대.
                    Image(uiImage: currentImage)
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: displayed.width * zoomScale,
                            height: displayed.height * zoomScale
                        )

                    // PencilKit 캔버스 — 전체 displayed 영역. zoomScale 영향 없음 → 흰 여백에도 그리기 가능.
                    PencilCanvasView(
                        initialDrawing: drawing,
                        onCanvasReady: { canvas in
                            if canvasView !== canvas {
                                canvasView = canvas
                                canvas.drawing = drawing
                                setupToolPicker(for: canvas)
                            }
                        },
                        onStrokeEnd: { newDrawing in
                            pushUndoSnapshot(overrideDrawing: lastCommittedDrawing)
                            lastCommittedDrawing = newDrawing
                            drawing = newDrawing
                        }
                    )
                    .frame(width: displayed.width, height: displayed.height)
                    .id(canvasReloadID)
                }
                .frame(width: displayed.width, height: displayed.height)
                .clipped()
                .rotationEffect(displayRotation)
                .animation(.easeInOut(duration: 0.3), value: displayRotation)
                .onAppear { displayedSize = displayed }
                .onChange(of: displayed) { _, new in displayedSize = new }
            }
        }
    }

    private func displaySize(for imgSize: CGSize, in container: CGSize) -> CGSize {
        guard imgSize.width > 0, imgSize.height > 0 else { return container }
        let scale = min(container.width / imgSize.width, container.height / imgSize.height)
        return CGSize(width: imgSize.width * scale, height: imgSize.height * scale)
    }

    /// 캔버스(이미지 + 펜) 의 여백 배경 — 외부 canvasArea 의 배경과 동일 톤.
    /// 사용자가 zoom 으로 이미지를 축소했을 때 보이는 여백이 외부 배경과 같은 색이라 자연스럽게 이어진다.
    private var canvasMarginColor: Color {
        colorScheme == .dark ? Color.black : Color(.systemGray6)
    }
    private var canvasMarginUIColor: UIColor {
        colorScheme == .dark ? .black : .systemGray6
    }

    // MARK: - Tool Picker

    private func setupToolPicker(for canvas: PKCanvasView) {
        toolPicker.setVisible(true, forFirstResponder: canvas)
        toolPicker.addObserver(canvas)
        canvas.becomeFirstResponder()
    }

    /// 공유/자르기 시트가 뜨기 전 호출 — 시스템 PKToolPicker 가 sheet 위로 새어 나오는 걸 막음.
    private func hideToolPicker() {
        guard let canvas = canvasView else { return }
        toolPicker.setVisible(false, forFirstResponder: canvas)
        canvas.resignFirstResponder()
    }

    /// 시트가 dismiss 된 뒤 호출 — 다시 마크업 가능 상태로.
    private func showToolPicker() {
        guard let canvas = canvasView else { return }
        toolPicker.setVisible(true, forFirstResponder: canvas)
        canvas.becomeFirstResponder()
    }

    // MARK: - Image Mutations

    /// 회전/자르기 결과를 currentImage 로 swap. 사이즈가 달라지면 기존 그림은 좌표가 어긋나므로 초기화.
    /// canvasReloadID 갱신으로 캔버스도 fresh 재생성.
    private func applyImage(_ newImage: UIImage) {
        currentImage = newImage
        drawing = PKDrawing()
        lastCommittedDrawing = PKDrawing()
        zoomScale = 1.0
        canvasReloadID = UUID()
    }

    /// 90° 단위 회전. (1) rotationEffect 로 0.3s 시각 회전 → (2) 비트맵 swap → (3) rotation 리셋.
    /// 시각 회전 종료 시점의 프레임과 swap 후 프레임이 동일해 점프 없이 자연스럽게 이어진다.
    private func rotate(byDegrees degrees: CGFloat) {
        guard !isRotating else { return }
        pushUndoSnapshot()
        isRotating = true
        displayRotation = .degrees(Double(degrees))

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let rotated = bitmapRotated(currentImage, byDegrees: degrees)
            // 애니메이션 끄고 한 transaction 안에서 swap + reset 해야 깜빡임 없음.
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                applyImage(rotated)
                displayRotation = .zero
            }
            isRotating = false
        }
    }

    /// CGImage 비트맵 자체를 회전한 새 UIImage 생성.
    private func bitmapRotated(_ image: UIImage, byDegrees degrees: CGFloat) -> UIImage {
        let radians = degrees * .pi / 180
        let originalSize = image.size
        let isQuarterTurn = abs(degrees.truncatingRemainder(dividingBy: 180)) == 90
        let newSize = isQuarterTurn
            ? CGSize(width: originalSize.height, height: originalSize.width)
            : originalSize

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            cg.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            cg.rotate(by: radians)
            image.draw(in: CGRect(
                x: -originalSize.width / 2,
                y: -originalSize.height / 2,
                width: originalSize.width,
                height: originalSize.height
            ))
        }
    }

    // MARK: - Undo

    /// 회전/자르기/줌/펜 stroke 어느 것이든 undoStack 에 쌓이도록 일원화.
    private var canUndo: Bool { !undoStack.isEmpty }

    /// 변형(회전/자르기/줌/펜 스트로크 종료) 직전 상태를 스택에 push. timestamp 함께 기록.
    /// 펜 stroke 의 경우 stroke END 시점에 호출하면서 `overrideDrawing` 으로 그 직전 lastCommittedDrawing
    /// 을 넘겨주면 SwiftUI @State 동기화 타이밍과 무관하게 정확한 pre-stroke 상태 보존됨.
    private func pushUndoSnapshot(overrideDrawing: PKDrawing? = nil) {
        undoStack.append(EditSnapshot(
            image: currentImage,
            drawing: overrideDrawing ?? drawing,
            zoomScale: zoomScale,
            timestamp: Date()
        ))
    }

    /// 가장 최근 스냅샷 pop → 직전 상태로 복원.
    /// canvasReloadID 를 갱신해 PencilKit 캔버스를 통째로 재생성. 이렇게 해야 PKCanvasView 의 stroke
    /// 렌더 캐시에 남는 이전 그림 잔상이 완전히 사라진다.
    private func performUndo() {
        guard let last = undoStack.popLast() else { return }
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            currentImage = last.image
            drawing = last.drawing
            zoomScale = last.zoomScale
        }
        lastCommittedDrawing = last.drawing
        canvasReloadID = UUID()  // 캔버스 fresh 재생성 → initialDrawing 으로 drawing State 사용
    }

    /// 매초 호출 — TTL 지난 snapshot 제거. 모두 만료되면 자연스럽게 undo 비활성화.
    private func pruneExpiredSnapshots() {
        let cutoff = Date().addingTimeInterval(-undoTTL)
        undoStack.removeAll { $0.timestamp < cutoff }
    }

    // MARK: - Compose

    /// currentImage + PKDrawing 합성.
    /// - 출력 캔버스 = currentImage.size (원본 해상도) 흰 배경.
    /// - 이미지는 zoomScale 만큼 가운데에 축소/확대.
    /// - 드로잉은 전체 캔버스(= 흰 여백 포함)에 깔림. PKDrawing 의 좌표계는 displayedSize (편집 화면
    ///   에서의 캔버스 frame) 이라 그 rect 로 추출 후 출력 캔버스 사이즈로 매핑.
    private func composeImage() -> UIImage {
        let canvasSize = currentImage.size
        let contentSize = CGSize(
            width: canvasSize.width * zoomScale,
            height: canvasSize.height * zoomScale
        )
        let contentRect = CGRect(
            x: (canvasSize.width - contentSize.width) / 2,
            y: (canvasSize.height - contentSize.height) / 2,
            width: contentSize.width,
            height: contentSize.height
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = currentImage.scale
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { ctx in
            // 여백 배경 — 편집 화면의 canvasArea 배경(systemGray6 / black) 과 동일 톤.
            canvasMarginUIColor.setFill()
            ctx.fill(CGRect(origin: .zero, size: canvasSize))

            // 이미지는 zoom 만큼 축소/확대된 contentRect 에.
            currentImage.draw(in: contentRect)

            // 드로잉은 전체 캔버스에. PKDrawing 좌표계는 displayedSize 기준이라 그 rect 로 추출.
            let drawingSourceSize = displayedSize == .zero ? canvasSize : displayedSize
            let drawingImage = drawing.image(
                from: CGRect(origin: .zero, size: drawingSourceSize),
                scale: currentImage.scale
            )
            drawingImage.draw(in: CGRect(origin: .zero, size: canvasSize))
        }
    }
}

// MARK: - Undo Snapshot

/// 회전/자르기/줌/펜 스트로크 직전 상태 한 묶음.
/// `timestamp` 는 만료 prune 에 사용 — 일정 시간 지나면 undo 비활성화.
private struct EditSnapshot {
    let image: UIImage
    let drawing: PKDrawing
    let zoomScale: CGFloat
    let timestamp: Date
}

// MARK: - PencilKit Bridge

private struct PencilCanvasView: UIViewRepresentable {
    /// 신규 canvas 생성 시 초기 drawing. 한 번 생성된 canvas 의 drawing 은 외부에서 직접 mutate
    /// (canvasView.drawing = ...) 하므로 @Binding 양방향 동기화는 쓰지 않는다.
    /// (양방향 binding + canvasViewDrawingDidChange 를 함께 두면 그리는 중 race 로 stroke 가
    /// 사라지거나 엉뚱한 곳에 잔상이 생기는 피드백 루프가 발생.)
    let initialDrawing: PKDrawing
    let onCanvasReady: (PKCanvasView) -> Void
    /// stroke 가 끝나 drawing 에 commit 된 직후 호출. 인자는 commit 직후의 새 PKDrawing.
    let onStrokeEnd: (PKDrawing) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = initialDrawing
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.delegate = context.coordinator
        // PKCanvasView (UIScrollView 자식) 내장 줌/스크롤 비활성화.
        canvas.minimumZoomScale = 1
        canvas.maximumZoomScale = 1
        canvas.isScrollEnabled = false
        canvas.pinchGestureRecognizer?.isEnabled = false
        DispatchQueue.main.async { onCanvasReady(canvas) }
        return canvas
    }

    /// drawing 동기화는 여기서 하지 않는다 — 단방향. parent 가 필요 시 canvasView.drawing 을 직접 set.
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PencilCanvasView
        init(_ parent: PencilCanvasView) { self.parent = parent }
        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            // stroke commit 직후 — 부모가 보관 중인 직전 상태를 push 하고 트래커 갱신.
            parent.onStrokeEnd(canvasView.drawing)
        }
    }
}

// MARK: - ShareSheet (UIActivityViewController)

/// `.sheet(item:)` 식별자.
private struct ShareItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - ScreenshotCropView (자르기 모달)

private struct ScreenshotCropView: View {
    let image: UIImage
    /// nil 이면 사용자가 취소.
    let onComplete: (UIImage?) -> Void

    @State private var cropRect: CGRect = .zero      // 화면 좌표계
    @State private var imageFrame: CGRect = .zero    // 화면 좌표계상 표시 이미지 영역
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().background(Color.white.opacity(0.2))
            cropArea
        }
        .background(Color.black.ignoresSafeArea())
    }

    private var topBar: some View {
        HStack {
            Button("취소", role: .cancel) { onComplete(nil) }
                .foregroundStyle(.white)
            Spacer()
            Text("자르기").font(.headline).foregroundStyle(.white)
            Spacer()
            Button("확인") { onComplete(performCrop()) }
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var cropArea: some View {
        GeometryReader { geo in
            let displayed = displaySize(for: image.size, in: geo.size)
            let origin = CGPoint(
                x: (geo.size.width - displayed.width) / 2,
                y: (geo.size.height - displayed.height) / 2
            )
            let frame = CGRect(origin: origin, size: displayed)

            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: displayed.width, height: displayed.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                CropOverlay(cropRect: $cropRect, imageFrame: frame)
            }
            .onAppear {
                imageFrame = frame
                if cropRect == .zero { cropRect = frame }
            }
            .onChange(of: geo.size) { _, _ in
                imageFrame = frame
                cropRect = frame
            }
        }
    }

    private func displaySize(for imgSize: CGSize, in container: CGSize) -> CGSize {
        guard imgSize.width > 0, imgSize.height > 0 else { return container }
        let scale = min(container.width / imgSize.width, container.height / imgSize.height)
        return CGSize(width: imgSize.width * scale, height: imgSize.height * scale)
    }

    /// 화면 좌표계의 cropRect 를 원본 이미지 좌표계로 변환 후 CGImage cropping 실행.
    private func performCrop() -> UIImage? {
        guard let cg = image.cgImage,
              imageFrame.width > 0, imageFrame.height > 0 else { return nil }
        // 표시 → 이미지 포인트 좌표
        let scaleX = image.size.width / imageFrame.width
        let scaleY = image.size.height / imageFrame.height
        let imgPointRect = CGRect(
            x: (cropRect.minX - imageFrame.minX) * scaleX,
            y: (cropRect.minY - imageFrame.minY) * scaleY,
            width: cropRect.width * scaleX,
            height: cropRect.height * scaleY
        )
        // 이미지 포인트 → CGImage 픽셀 좌표 (image.scale 반영)
        let px = imgPointRect.applying(CGAffineTransform(scaleX: image.scale, y: image.scale))
        guard let croppedCG = cg.cropping(to: px) else { return nil }
        return UIImage(cgImage: croppedCG, scale: image.scale, orientation: image.imageOrientation)
    }
}

// MARK: - CropOverlay (자르기 박스 + 모서리 핸들)

private struct CropOverlay: View {
    @Binding var cropRect: CGRect
    let imageFrame: CGRect
    private let handleSize: CGFloat = 24
    private let minSize: CGFloat = 50

    /// 드래그 시작 시 모서리 위치를 기억해서 translation 만큼 더해 새 위치 계산.
    /// .local / .global 좌표계 변환 없이 translation 만 쓰면 핸들의 자체 frame 영향에서 자유.
    @State private var dragOriginByCorner: [Corner: CGPoint] = [:]

    var body: some View {
        ZStack {
            // 어두운 dim 마스크 (cropRect 부분만 cutout).
            Path { path in
                path.addRect(.infinite)
                path.addRect(cropRect)
            }
            .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
            .allowsHitTesting(false)

            // 흰 테두리.
            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: cropRect.width, height: cropRect.height)
                .position(x: cropRect.midX, y: cropRect.midY)
                .allowsHitTesting(false)

            // 4 모서리 핸들.
            ForEach(Corner.allCases, id: \.self) { corner in
                handle
                    .position(corner.point(in: cropRect))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let origin = dragOriginByCorner[corner]
                                    ?? corner.point(in: cropRect)
                                if dragOriginByCorner[corner] == nil {
                                    dragOriginByCorner[corner] = origin
                                }
                                let newPoint = CGPoint(
                                    x: origin.x + value.translation.width,
                                    y: origin.y + value.translation.height
                                )
                                update(corner: corner, to: newPoint)
                            }
                            .onEnded { _ in
                                dragOriginByCorner[corner] = nil
                            }
                    )
            }
        }
    }

    private var handle: some View {
        Circle()
            .fill(Color.white)
            .frame(width: handleSize, height: handleSize)
            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
    }

    /// 드래그된 새 위치로 모서리를 옮겨 cropRect 갱신.
    /// imageFrame 안에서만 움직이게 clamp + minSize 유지.
    private func update(corner: Corner, to point: CGPoint) {
        var rect = cropRect
        let clampedX = min(max(point.x, imageFrame.minX), imageFrame.maxX)
        let clampedY = min(max(point.y, imageFrame.minY), imageFrame.maxY)
        switch corner {
        case .topLeft:
            rect.origin.x = min(clampedX, rect.maxX - minSize)
            rect.origin.y = min(clampedY, rect.maxY - minSize)
            rect.size.width = cropRect.maxX - rect.origin.x
            rect.size.height = cropRect.maxY - rect.origin.y
        case .topRight:
            let newMaxX = max(clampedX, rect.minX + minSize)
            rect.origin.y = min(clampedY, rect.maxY - minSize)
            rect.size.width = newMaxX - rect.minX
            rect.size.height = cropRect.maxY - rect.origin.y
        case .bottomLeft:
            rect.origin.x = min(clampedX, rect.maxX - minSize)
            let newMaxY = max(clampedY, rect.minY + minSize)
            rect.size.width = cropRect.maxX - rect.origin.x
            rect.size.height = newMaxY - rect.minY
        case .bottomRight:
            let newMaxX = max(clampedX, rect.minX + minSize)
            let newMaxY = max(clampedY, rect.minY + minSize)
            rect.size.width = newMaxX - rect.minX
            rect.size.height = newMaxY - rect.minY
        }
        cropRect = rect
    }

    enum Corner: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
        func point(in r: CGRect) -> CGPoint {
            switch self {
            case .topLeft:     return CGPoint(x: r.minX, y: r.minY)
            case .topRight:    return CGPoint(x: r.maxX, y: r.minY)
            case .bottomLeft:  return CGPoint(x: r.minX, y: r.maxY)
            case .bottomRight: return CGPoint(x: r.maxX, y: r.maxY)
            }
        }
    }
}
