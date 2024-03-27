// import 'package:ntfy_dart/ntfy_dart.dart';

// class NtfyInterface {
//   final NtfyClient _client = NtfyClient();

//   void changeBasePath(Uri basePath) {
//     _client.changeBasePath(basePath);
//   }

//   Future<MessageResponse> publish(PublishableMessage message) {
//     return _client.publishMessage(message);
//   }

//   Future<List<MessageResponse>> poll(PollWrapper opts) {
//     return _client.pollMessages(opts.topics,
//         since: opts.since,
//         scheduled: opts.scheduled ?? false,
//         filters: opts.filters);
//   }

//   Future<Stream<MessageResponse>> getMessageStream(List<String> topics,
//       {FilterOptions? filters}) {
//     return _client.getMessageStream(topics, filters: filters);
//   }
// }

// class PollWrapper {
//   List<String> topics;

//   DateTime? since;

//   bool? scheduled;

//   FilterOptions? filters;

//   PollWrapper(this.topics);
// }
