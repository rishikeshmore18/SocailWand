//
//  UploadOptionsMenu.swift
//  social wand
//

import SwiftUI

enum UploadSource {
    case photoLibrary
    case camera
    case files
}

struct UploadOptionsMenu: View {
    let title: String
    let onSelect: (UploadSource) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppBrand.textPrimary)
                .padding(.top, 6)
            
            MenuOptionButton(
                icon: "photo.on.rectangle",
                title: "Choose from Photos",
                subtitle: "Select up to 5 photos"
            ) {
                onSelect(.photoLibrary)
            }
            
            MenuOptionButton(
                icon: "camera",
                title: "Take Photo",
                subtitle: "Use your camera"
            ) {
                onSelect(.camera)
            }
            
            MenuOptionButton(
                icon: "doc",
                title: "Upload File",
                subtitle: "Choose from Files app"
            ) {
                onSelect(.files)
            }
            
            Button("Cancel") {
                onCancel()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(AppBrand.purple)
            .padding(.top, 6)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppBrand.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppBrand.cardBorder, lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
}

private struct MenuOptionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppBrand.purple)
                    .frame(width: 44, height: 44)
                    .background(AppBrand.iconBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppBrand.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(AppBrand.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppBrand.textHint)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppBrand.dim)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppBrand.cardBorder.opacity(0.9), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
