import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

struct TVQRCode: View {
  let text: String
  let size: CGFloat

  var body: some View {
    Group {
      if let image = Self.image(for: text) {
        Image(decorative: image, scale: 1)
          .interpolation(.none)
          .resizable()
          .padding(20)
          .background(Color.white)
      } else {
        TVPalette.surfaceRaised
      }
    }
    .frame(width: size, height: size)
    .clipShape(RoundedRectangle(cornerRadius: TVDimens.panelRadius))
  }

  private static func image(for text: String) -> CGImage? {
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(text.utf8)
    filter.correctionLevel = "M"
    guard let output = filter.outputImage else { return nil }
    return CIContext().createCGImage(output, from: output.extent)
  }
}
