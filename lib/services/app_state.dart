import 'package:flutter/material.dart';

class AppState extends ChangeNotifier {
  int currentTab = 0;
  bool obscureBalance = true;
  String? faqTopicFilter;
  String? faqCategoryFilter;
  String? highlightedTransactionId;

  void navigateTo(int index) {
    if (currentTab == index) return;
    currentTab = index;
    notifyListeners();
  }

  // Toggles the balance visibility
  void toggleBalance() {
    obscureBalance = !obscureBalance;
    notifyListeners();
  }

  // Explicitly un-obscure (used by voice command)
  void revealBalance() {
    if (!obscureBalance) return;
    obscureBalance = false;
    notifyListeners();
  }

  void setFaqFilter(String topic, String category) {
    if (faqTopicFilter == topic && faqCategoryFilter == category) return;
    faqTopicFilter = topic;
    faqCategoryFilter = category;
    notifyListeners();
  }

  void clearFaqFilter() {
    if (faqTopicFilter == null && faqCategoryFilter == null) return;
    faqTopicFilter = null;
    faqCategoryFilter = null;
    notifyListeners();
  }

  void setHighlightedTransaction(String id) {
    if (highlightedTransactionId == id) return;
    highlightedTransactionId = id;
    notifyListeners();
  }
}
