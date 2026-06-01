/// Benjamin Franklin's thirteen virtues, in his own canonical order (never
/// alphabetical), with his precepts. Used as an optional seed set and for the
/// "virtue of the week" rotation. Precepts are runtime-overridable via the
/// UserPrefs key `virtuePrecept_<key>` (override UI deferred; the key exists).
class Virtue {
  final String key;
  final String name;
  final String precept;
  const Virtue(this.key, this.name, this.precept);
}

const List<Virtue> kFranklinVirtues = [
  Virtue('temperance', 'Temperance',
      'Eat not to dullness; drink not to elevation.'),
  Virtue('silence', 'Silence',
      'Speak not but what may benefit others or yourself; avoid trifling conversation.'),
  Virtue('order', 'Order',
      'Let all your things have their places; let each part of your business have its time.'),
  Virtue('resolution', 'Resolution',
      'Resolve to perform what you ought; perform without fail what you resolve.'),
  Virtue('frugality', 'Frugality',
      'Make no expense but to do good to others or yourself, i.e., waste nothing.'),
  Virtue('industry', 'Industry',
      'Lose no time; be always employed in something useful; cut off all unnecessary actions.'),
  Virtue('sincerity', 'Sincerity',
      'Use no hurtful deceit; think innocently and justly, and, if you speak, speak accordingly.'),
  Virtue('justice', 'Justice',
      'Wrong none by doing injuries or omitting the benefits that are your duty.'),
  Virtue('moderation', 'Moderation',
      'Avoid extremes; forbear resenting injuries so much as you think they deserve.'),
  Virtue('cleanliness', 'Cleanliness',
      'Tolerate no uncleanliness in body, clothes, or habitation.'),
  Virtue('tranquillity', 'Tranquillity',
      'Be not disturbed at trifles, or at accidents common or unavoidable.'),
  Virtue('chastity', 'Chastity',
      'Rarely use venery but for health or offspring, never to dullness, weakness, or the injury of your own or another\'s peace or reputation.'),
  Virtue('humility', 'Humility', 'Imitate Jesus and Socrates.'),
];

/// The virtue Franklin focused on for a given week, derived from a Monday
/// anchor date independent of any habit rows: `virtues[weeksSinceAnchor % 13]`.
Virtue virtueOfWeek(DateTime anchorMonday, DateTime now) {
  final weeks = now.difference(anchorMonday).inDays ~/ 7;
  final idx = ((weeks % 13) + 13) % 13; // guard negatives
  return kFranklinVirtues[idx];
}
