// import 'dart:typed_data';
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw;

// Future<Uint8List> createPdf() async {
//   // Create the PDF document
//   final pdf = pw.Document();

//   // Add a title to the PDF
//   pdf.addPage(pw.Page(
//     build: (context) {
//       return pw.Center(
//         child: pw.Text(
//           "${widget.participant.name}'s Answers",
//           style: pw.TextStyle(
//             fontSize: 24,
//             fontWeight: pw.FontWeight.bold,
//           ),
//         ),
//       );
//     },
//   ));

//   // Add the participant's answers to the PDF
//   for (String surveyId in widget.participant.surveyAnswers.keys) {
//     List<dynamic> answers = widget.participant.surveyAnswers[surveyId]!;
//     Map<String, dynamic> questionData = widget.survey.questions[int.parse(surveyId.substring(1))];
//     String question = questionData['question'];
//     List<String>? options = questionData['options'] as List<String>? ?? ['True', 'False'];

//     List<dynamic>? correctAnswers = questionData['correctAnswers'] as List<dynamic>?;
//     bool isMultiCorrect = correctAnswers != null && correctAnswers.length > 1;

//     pdf.addPage(pw.Page(
//       build: (context) {
//         return pw.Column(
//           crossAxisAlignment: pw.CrossAxisAlignment.start,
//           children: [
//             pw.Text(
//               question,
//               style: pw.TextStyle(
//                 fontSize: 18,
//                 fontWeight: pw.FontWeight.bold,
//               ),
//             ),
//             pw.SizedBox(height: 8),
//             for (int optionIndex = 0; optionIndex < options.length; optionIndex++)
//               pw.Row(
//                 crossAxisAlignment: pw.CrossAxisAlignment.start,
//                 children: [
//                   pw.Padding(
//                     padding: pw.EdgeInsets.only(top: 3),
//                     child: pw.Text(
//                       options[optionIndex],
//                       style: pw.TextStyle(
//                         fontSize: 16,
//                       ),
//                     ),
//                   ),
//                   pw.SizedBox(width: 16),
//                   if (answers.contains(optionIndex))
//                     pw.Icon(pw.FontAwesomeIcons.check, size: 16, color: PdfColors.green)
//                   else
//                     pw.Icon(pw.FontAwesomeIcons.square, size: 16),
//                 ],
//               ),
//             if (isMultiCorrect)
//               pw.Text(
//                 "Correct answers: ${correctAnswers!.map((answer) => options[answer]).join(', ')}",
//                 style: pw.TextStyle(
//                   fontSize: 16,
//                   fontWeight: pw.FontWeight.bold,
//                   color: PdfColors.green,
//                 ),
//               ),
//             pw.SizedBox(height: 16),
//           ],
//         );
//       },
//     ));
//   }

//   // Add the overall score to the PDF
//   pdf.addPage(pw.Page(
//     build: (context) {
//       return pw.Center(
//         child: pw.Text(
//           "Total Score: ${calculateOverallScore().toStringAsFixed(1)}%",
//           style: pw.TextStyle(
//             fontSize: 24,
//             fontWeight: pw.FontWeight.bold,
//           ),
//         ),
//       );
//     },
//   ));

//   // Save the PDF document to a byte array
//   return pdf.save();
// }
