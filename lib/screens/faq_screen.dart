import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/tts_service.dart';
import '../../services/app_state.dart';
import '../../utils/app_feedback.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tts = Provider.of<TTSService>(context, listen: false);
    final appState = Provider.of<AppState>(context);

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('FAQ')
        .orderBy(
          'createdAt',
          descending: true,
        ); // Remember FAQ collection name is uppercase
    if (appState.faqTopicFilter != null && appState.faqCategoryFilter != null) {
      query = query
          .where('topic', isEqualTo: appState.faqTopicFilter)
          .where('category', isEqualTo: appState.faqCategoryFilter);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ɲininkaliw ani Dɛmɛ"),
        actions: [
          if (appState.faqTopicFilter != null)
            TextButton.icon(
              icon: const Icon(Icons.clear_all, color: Colors.blue),
              label: const Text("k'a bɛ jira"),
              onPressed: () => appState.clearFaqFilter(),
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('[UI:faq] stream failed: ${snapshot.error}');
            return const Center(
              child: Text(
                'Ɲininkaliw ma se ka sɔrɔ.',
                style: TextStyle(color: Colors.red),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            debugPrint(
              "Topic filter: ${appState.faqTopicFilter}; Category filter: ${appState.faqCategoryFilter} data:${snapshot.data!.docs}",
            );
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Anw ma se ka jaabi sɔrɔ ni ɲininkali la"),
                  const SizedBox(height: 16),
                  if (appState.faqTopicFilter != null)
                    ElevatedButton(
                      onPressed: () => appState.clearFaqFilter(),
                      child: const Text("Ka segin kɔ"),
                    ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              final data = doc.data();

              String question = data['question'] ?? '';
              String answer = data['answer'] ?? '';
              String topic = data['topic'] ?? '';
              String category = data['category'] ?? '';
              bool isFiltered = appState.faqTopicFilter != null;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                child: ExpansionTile(
                  initiallyExpanded: isFiltered,
                  title: Text(
                    question,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        Chip(
                          label: Text(
                            topic,
                            style: const TextStyle(fontSize: 11),
                          ),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.blue.shade50,
                          side: BorderSide.none,
                        ),
                        Chip(
                          label: Text(
                            category,
                            style: const TextStyle(fontSize: 11),
                          ),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.grey.shade200,
                          side: BorderSide.none,
                        ),
                      ],
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              answer,
                              style: const TextStyle(
                                height: 1.4,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.volume_up,
                              color: Colors.blue,
                            ),
                            onPressed:
                                () => AppFeedback.speak(
                                  context,
                                  tts,
                                  "$question. $answer",
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
