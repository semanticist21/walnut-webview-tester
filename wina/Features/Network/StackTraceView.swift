//
//  StackTraceView.swift
//  wina
//
//  Display JavaScript stack trace for request initiator tracking.
//

import SwiftUI

struct StackTraceView: View {
    let stackFrames: [StackFrame]?
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.right.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.blue)

                Text(verbatim: "Initiator Stack Trace")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                if let frames = stackFrames, !frames.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 4)

            // Content
            if let frames = stackFrames, !frames.isEmpty {
                if isExpanded {
                    stackTraceContent(frames)
                } else {
                    collapsedPreview(frames)
                }
            } else {
                Text("No stack trace available")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Collapsed Preview

    @ViewBuilder
    private func collapsedPreview(_ frames: [StackFrame]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let first = frames.first {
                HStack(spacing: 4) {
                    Text("▶")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(width: 6)

                    Text(first.functionName)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("(\(first.displayFileName))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()
                }
            }

            if frames.count > 1 {
                Text("+ \(frames.count - 1) more frames")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Expanded Content

    @ViewBuilder
    private func stackTraceContent(_ frames: [StackFrame]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(frames.enumerated()), id: \.element.id) { index, frame in
                stackFrameRow(frame, index: index)
            }
        }
    }

    @ViewBuilder
    private func stackFrameRow(_ frame: StackFrame, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // Function name with index
            HStack(spacing: 4) {
                Text("\(index + 1)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 16, alignment: .trailing)

                Text("▶")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .frame(width: 6)

                Text(frame.functionName)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)

                Spacer()
            }

            // File location
            HStack(spacing: 0) {
                Text("")
                    .frame(width: 16)
                Text("")
                    .frame(width: 6)

                Text("\(frame.displayFileName):\(frame.lineNumber):\(frame.columnNumber)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let frames = [
        StackFrame(functionName: "fetchUserData", fileName: "api/users.js", lineNumber: 45, columnNumber: 12),
        StackFrame(functionName: "onLoginClick", fileName: "pages/login.js", lineNumber: 120, columnNumber: 5),
        StackFrame(functionName: "handleFormSubmit", fileName: "components/form.js", lineNumber: 78, columnNumber: 8),
        StackFrame(functionName: "addEventListener", fileName: "utils/events.js", lineNumber: 23, columnNumber: 3)
    ]

    ScrollView {
        VStack(spacing: 20) {
            // With frames
            StackTraceView(stackFrames: frames)

            // Empty state
            StackTraceView(stackFrames: nil)

            // Empty array
            StackTraceView(stackFrames: [])
        }
        .padding()
    }
}
