import SwiftUI
import UIKit
import Photos

struct BonusBackgroundsSheetView: View {
    @AppStorage(AppSettingsKeys.interfaceTintHex) private var interfaceTintHex = AppSettingsDefaults.interfaceTintHex

    @State private var saveAlert: BonusBackgroundSaveAlert?
    @State private var isSaving = false

    private let assets = BonusBackgroundAsset.all
    private let columns = Array(
        repeating: GridItem(.flexible(minimum: 88), spacing: 16),
        count: 3
    )

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    introContent
                    assetGrid
                }
                .padding(.horizontal, 32)
                .padding(.top, 64)
                .padding(.bottom, 132)
            }
            .background(Color(.systemBackground))
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomDownloadBar(
                    viewportWidth: proxy.size.width,
                    bottomSafeAreaInset: proxy.safeAreaInsets.bottom
                )
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .alert(item: $saveAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var introContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "giftcard.fill")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28, alignment: .leading)
                .accessibilityHidden(true)

            Text("To help your Moments feel right at home on your screen, I put together a few backgrounds I made for myself.")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .lineSpacing(0)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var assetGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(assets) { asset in
                BonusBackgroundTile(asset: asset)
            }
        }
    }

    private func bottomDownloadBar(
        viewportWidth: CGFloat,
        bottomSafeAreaInset: CGFloat
    ) -> some View {
        BottomGlassActionBar(
            showsPrimaryAction: true,
            maxContentWidth: readableContentWidth(
                for: viewportWidth,
                horizontalPadding: 24
            ),
            bottomSafeAreaInset: bottomSafeAreaInset,
            bottomBlurGradientHeight: 96
        ) {
            VStack(spacing: 10) {
                Button {
                    save(assets)
                } label: {
                    Text(isSaving ? "Downloading" : "Download")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .controlSize(.small)
                .buttonBorderShape(.capsule)
                .adaptiveGlassProminentButtonStyle()
                .tint(primaryButtonColor)
                .foregroundStyle(primaryButtonLabelColor)
                .disabled(isSaving || assets.isEmpty)
                .accessibilityLabel("Download Backgrounds")

                Text("Backgrounds will be downloaded to your Photos app")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func readableContentWidth(for viewportWidth: CGFloat, horizontalPadding: CGFloat) -> CGFloat {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return .infinity }
        return min(700, max(viewportWidth - (horizontalPadding * 2), 0))
    }

    private var primaryButtonColor: Color {
        AppTheme.baseInterfaceTintColor(from: interfaceTintHex)
    }

    private var primaryButtonLabelColor: Color {
        primaryButtonColor.prefersLightForeground ? .white : .black
    }

    private func save(_ assets: [BonusBackgroundAsset]) {
        guard !isSaving else { return }

        let images = assets.map(\.image)
        guard !images.isEmpty else {
            saveAlert = .unableToLoad
            return
        }

        isSaving = true

        Task {
            do {
                try await BonusBackgroundPhotoSaver.save(images)
                await MainActor.run {
                    isSaving = false
                    saveAlert = .saved(count: images.count)
                }
            } catch BonusBackgroundPhotoSaver.SaveError.notAuthorized {
                await MainActor.run {
                    isSaving = false
                    saveAlert = .notAuthorized
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    saveAlert = .failed
                }
            }
        }
    }
}

private struct BonusBackgroundTile: View {
    let asset: BonusBackgroundAsset

    var body: some View {
        Image(uiImage: asset.image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct BonusBackgroundAsset: Identifiable {
    let name: String
    let image: UIImage

    var id: String { name }

    static let all: [BonusBackgroundAsset] = {
        (1...99).compactMap { index in
            let name = "\(index)"
            guard let image = UIImage(named: name) else { return nil }
            return BonusBackgroundAsset(name: name, image: image)
        }
    }()
}

private enum BonusBackgroundPhotoSaver {
    enum SaveError: Error {
        case notAuthorized
        case saveFailed
    }

    static func save(_ images: [UIImage]) async throws {
        let hasAccess = await requestAddOnlyAccess()
        guard hasAccess else {
            throw SaveError.notAuthorized
        }

        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                images.forEach { image in
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? SaveError.saveFailed)
                }
            }
        }
    }

    private static func requestAddOnlyAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status == .authorized || status == .limited)
            }
        }
    }
}

private struct BonusBackgroundSaveAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    static func saved(count: Int) -> BonusBackgroundSaveAlert {
        BonusBackgroundSaveAlert(
            title: "Saved",
            message: count == 1
                ? "The background was saved to Photos, you can add it to your widgets now."
                : "The backgrounds were saved to Photos, you can add them to your widgets now."
        )
    }

    static let unableToLoad = BonusBackgroundSaveAlert(
        title: "Unable to Load",
        message: "These backgrounds could not be loaded."
    )

    static let notAuthorized = BonusBackgroundSaveAlert(
        title: "Photos Access Needed",
        message: "Allow Moments to add images to Photos, then try again."
    )

    static let failed = BonusBackgroundSaveAlert(
        title: "Unable to Save",
        message: "The backgrounds could not be saved."
    )
}
