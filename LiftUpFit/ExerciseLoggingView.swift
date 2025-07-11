//
//  ExerciseLoggingView.swift
//  LiftUpFit
//
//  Created by Richard Slagle on 6/29/25.
//

import SwiftUI

struct ExerciseLoggingView: View {
    let exercise: Exercise
    let sets: Int
    @Binding var setLogs: [SetLog]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exercise.name)
                .font(.headline)
            ForEach(0..<sets, id: \.self) { idx in
                HStack {
                    TextField("Lbs", value: $setLogs[idx].weight, formatter: NumberFormatter())
                        .keyboardType(.decimalPad)
                        .frame(width: 60)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("Reps", value: $setLogs[idx].reps, formatter: NumberFormatter())
                        .keyboardType(.numberPad)
                        .frame(width: 60)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Spacer()
                    Button(action: {
                        setLogs[idx].completed.toggle()
                    }) {
                        Image(systemName: setLogs[idx].completed ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(setLogs[idx].completed ? .green : .gray)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.vertical, 8)
    }
}
