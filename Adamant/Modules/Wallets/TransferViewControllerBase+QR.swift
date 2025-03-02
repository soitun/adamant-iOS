//
//  TransferViewControllerBase+QR.swift
//  Adamant
//
//  Created by Anokhov Pavel on 29.08.2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import UIKit
@preconcurrency import QRCodeReader
import EFQRCode
import AVFoundation
import Photos
import CommonKit

// MARK: - QR
extension TransferViewControllerBase {
    func scanQr() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            qrReader.modalPresentationStyle = .overFullScreen
            
            DispatchQueue.onMainAsync {
                self.present(self.qrReader, animated: true, completion: nil)
            }
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] (granted: Bool) in
                DispatchQueue.onMainAsync {
                    if granted, let qrReader = self?.qrReader {
                        qrReader.modalPresentationStyle = .overFullScreen
                        self?.present(qrReader, animated: true, completion: nil)
                    }
                }
            }
        case .restricted:
            let alert = UIAlertController(title: nil, message: String.adamant.login.cameraNotSupported, preferredStyleSafe: .alert, source: nil)
            alert.addAction(UIAlertAction(title: String.adamant.alert.ok, style: .cancel, handler: nil))
            alert.modalPresentationStyle = .overFullScreen

            DispatchQueue.onMainAsync {
                self.present(alert, animated: true, completion: nil)
            }
            
        case .denied:
            let alert = UIAlertController(title: nil, message: String.adamant.login.cameraNotAuthorized, preferredStyleSafe: .alert, source: nil)
            
            alert.addAction(UIAlertAction(title: String.adamant.alert.settings, style: .default) { _ in
                DispatchQueue.main.async {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
                    }
                }
            })
            
            alert.addAction(UIAlertAction(title: String.adamant.alert.cancel, style: .cancel, handler: nil))
            alert.modalPresentationStyle = .overFullScreen
            
            DispatchQueue.onMainAsync {
                self.present(alert, animated: true, completion: nil)
            }
        @unknown default:
            break
        }
    }
    
    func loadQr() {
        let presenter: () -> Void = { [weak self] in
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.allowsEditing = false
            picker.sourceType = .photoLibrary
            picker.modalPresentationStyle = .overFullScreen
            picker.overrideUserInterfaceStyle = .light
            self?.present(picker, animated: true, completion: nil)
        }
        
        presenter()
    }
}

// MARK: - ButtonsStripeViewDelegate
extension TransferViewControllerBase: ButtonsStripeViewDelegate {
    func buttonsStripe(didTapButton button: StripeButtonType) {
        switch button {
        case .qrCameraReader:
            scanQr()
            
        case .qrPhotoReader:
            loadQr()
            
        default:
            return
        }
    }
}

// MARK: - UIImagePickerControllerDelegate
extension TransferViewControllerBase: UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        dismiss(animated: true, completion: nil)
        
        guard let image = info[.originalImage] as? UIImage, let cgImage = image.cgImage else {
            return
        }
        
        let codes = EFQRCode.recognize(cgImage)
        
        if codes.contains(where: { handleRawAddress($0) }) {
            vibroService.applyVibration(.medium)
            return
        }
        
        if codes.isEmpty {
            dialogService.showWarning(withMessage: String.adamant.login.noQrError)
        } else {
            dialogService.showWarning(withMessage: String.adamant.newChat.wrongQrError)
        }
    }
}

// MARK: - QRCodeReaderViewControllerDelegate
extension TransferViewControllerBase: QRCodeReaderViewControllerDelegate {
    nonisolated func reader(_ reader: QRCodeReaderViewController, didScanResult result: QRCodeReaderResult) {
        Task { @MainActor in
            if handleRawAddress(result.value) {
                vibroService.applyVibration(.medium)
                dismiss(animated: true, completion: nil)
            } else {
                dialogService.showWarning(withMessage: String.adamant.newChat.wrongQrError)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    reader.startScanning()
                }
            }
        }
    }
    
    nonisolated func readerDidCancel(_ reader: QRCodeReaderViewController) {
        Task { @MainActor in
            reader.dismiss(animated: true, completion: nil)
        }
    }
}
