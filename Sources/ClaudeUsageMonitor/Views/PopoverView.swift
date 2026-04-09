import SwiftUI

struct PopoverView: View {
    @ObservedObject var authService: AuthService
    @ObservedObject var usageService: UsageService
    @ObservedObject var pollingService: PollingService

    var body: some View {
        if authService.isAuthenticated {
            authenticatedView
        } else {
            SetupView(authService: authService)
        }
    }

    private var authenticatedView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Constants.appName)
                        .font(DS.Font.h1)
                    if let plan = usageService.userInfo?.plan,
                       let email = usageService.userInfo?.email {
                        Text("\(plan) · \(email)")
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Color.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, DS.Space._4)
            .padding(.top, DS.Space._3)
            .padding(.bottom, DS.Space._2)

            Divider()

            // Gauge
            if let primary = usageService.usage?.primaryBucket {
                UsageGaugeView(
                    percentage: primary.utilization,
                    resetDate: primary.resetDate
                )
                .padding(.vertical, DS.Space._4)
            } else if usageService.isLoading {
                ProgressView()
                    .frame(height: 140)
            } else {
                Text("No usage data")
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.secondary)
                    .frame(height: 140)
            }

            Divider()
                .padding(.horizontal, DS.Space._4)

            // Usage rows
            if let usage = usageService.usage {
                VStack(spacing: 0) {
                    ForEach(Array(usage.allBuckets.enumerated()), id: \.offset) { index, item in
                        UsageBucketRow(label: item.label, bucket: item.bucket)
                            .padding(.horizontal, DS.Space._4)
                            .padding(.vertical, DS.Space._2 + 2)

                        if index < usage.allBuckets.count - 1 {
                            Divider()
                                .padding(.horizontal, DS.Space._4)
                        }
                    }

                    if let extra = usage.extraUsage, extra.isEnabled == true {
                        Divider()
                            .padding(.horizontal, DS.Space._4)
                        HStack {
                            Text("Extra Usage")
                                .font(DS.Font.body)
                            Spacer()
                            Text("$\(String(format: "%.2f", extra.usedDollars)) / $\(String(format: "%.2f", extra.limitDollars))")
                                .font(DS.Font.value)
                                .foregroundStyle(DS.Color.secondary)
                        }
                        .padding(.horizontal, DS.Space._4)
                        .padding(.vertical, DS.Space._2 + 2)
                    }
                }
            }

            Divider()
                .padding(.horizontal, DS.Space._4)

            // Footer: clickable refresh status + Settings + Quit
            VStack(spacing: DS.Space._2) {
                if let error = usageService.error {
                    ScrollView {
                        Text(error.localizedDescription)
                            .font(DS.Font.error)
                            .foregroundStyle(DS.Color.destructive)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxHeight: 50)
                }

                HStack {
                    // Combined refresh + status: "↻ Updated just now"
                    Button(action: { pollingService.refreshNow() }) {
                        HStack(spacing: DS.Space._1) {
                            Image(systemName: "arrow.clockwise")
                            TimelineView(.periodic(from: .now, by: 30)) { context in
                                if usageService.isLoading {
                                    Text("Updating...")
                                } else if let lastUpdated = usageService.lastUpdated {
                                    Text("Updated \(DateFormatting.relativeTime(from: lastUpdated, to: context.date))")
                                } else {
                                    Text("Refresh")
                                }
                            }
                        }
                    }
                    .disabled(usageService.isLoading)

                    Spacer()

                    SettingsLink {
                        Image(systemName: "gear")
                    }

                    Button(action: { NSApp.terminate(nil) }) {
                        Image(systemName: "power")
                    }
                }
                .buttonStyle(.borderless)
                .font(DS.Font.button)
            }
            .padding(.horizontal, DS.Space._4)
            .padding(.vertical, DS.Space._4)
        }
    }
}
