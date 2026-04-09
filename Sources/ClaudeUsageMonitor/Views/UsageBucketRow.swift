import SwiftUI

struct UsageBucketRow: View {
    let label: String
    let bucket: UsageBucket

    var body: some View {
        HStack {
            Text(label)
                .font(DS.Font.body)
                .frame(width: 100, alignment: .leading)

            ProgressView(value: bucket.utilization, total: 100)
                .tint(DS.Color.usage(bucket.utilization))

            Text("\(Int(bucket.utilization))%")
                .font(DS.Font.value)
                .foregroundStyle(DS.Color.usage(bucket.utilization))
                .frame(width: 44, alignment: .trailing)
        }
    }
}
