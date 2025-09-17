/// Canonical Spiritual Gift definitions (24 gifts) used to backfill UI
/// These will be replaced by backend-provided authoritative content when available.
/// Keys are normalized slugs produced by `_slugify` logic (lowercase, hyphenated, '&' -> 'and').

const Map<String, Map<String, String>> kCanonicalSpiritualGiftDefinitions = {
  'leadership': {
    'name': 'Leadership',
    'desc': 'Spirit-enabled capacity to cast God-honoring vision, align people, and sustain momentum toward mission.',
    'refs': 'Romans 12:8; Hebrews 13:7'
  },
  'pastor-shepherd': {
    'name': 'Pastor/Shepherd',
    'desc': 'Ability to nurture, guard, and guide a group toward maturity in Christ over time.',
    'refs': 'Ephesians 4:11-12; 1 Peter 5:2-3'
  },
  'discernment': {
    'name': 'Discernment',
    'desc': 'Spirit-given insight to distinguish truth from error, authentic from counterfeit influences.',
    'refs': '1 Corinthians 12:10; 1 John 4:1'
  },
  'exhortation': {
    'name': 'Exhortation (Encouragement)',
    'desc': 'Ability to strengthen, comfort, and urge others toward faithful growth and obedience.',
    'refs': 'Romans 12:8; Acts 14:21-22'
  },
  'hospitality': {
    'name': 'Hospitality',
    'desc': 'Capacity to create welcoming, safe, and relationally fertile environments that advance kingdom community.',
    'refs': '1 Peter 4:9-10; Romans 12:13'
  },
  'prophecy': {
    'name': 'Prophecy',
    'desc': 'Spirit-prompted ability to deliver timely truth or correction aligned with Scripture for building up.',
    'refs': 'Romans 12:6; 1 Corinthians 14:3'
  },
  'knowledge': {
    'name': 'Knowledge',
    'desc': 'Capacity to grasp, retain, and integrate biblical truth for timely, edifying application.',
    'refs': '1 Corinthians 12:8; Colossians 1:9-10'
  },
  'miracles': {
    'name': 'Miracles',
    'desc': 'God-empowered acts that authenticate His power and advance His purposes in extraordinary ways.',
    'refs': '1 Corinthians 12:10; Acts 19:11-12'
  },
  'healing': {
    'name': 'Healing',
    'desc': 'Spirit-enabled channels of God’s restorative power—physical, emotional, or spiritual.',
    'refs': '1 Corinthians 12:9; Acts 3:6-8'
  },
  'helps': {
    'name': 'Helps',
    'desc': 'Willing, behind-the-scenes assistance that strengthens others’ effectiveness and endurance.',
    'refs': '1 Corinthians 12:28; Romans 16:1-2'
  },
  'mercy': {
    'name': 'Mercy',
    'desc': 'Compassionate empathy that moves toward relieving suffering with tangible care.',
    'refs': 'Romans 12:8; Luke 10:33-37'
  },
  'evangelism': {
    'name': 'Evangelism',
    'desc': 'Spirit-empowered clarity and passion to communicate the gospel for receptive response.',
    'refs': 'Ephesians 4:11; Acts 8:5-12'
  },
  'faith': {
    'name': 'Faith',
    'desc': 'Extraordinary confidence in God’s character and promises that inspires bold risk and perseverance.',
    'refs': '1 Corinthians 12:9; Hebrews 11'
  },
  'teaching': {
    'name': 'Teaching',
    'desc': 'Ability to clarify and communicate God’s truth so others gain accurate understanding and obedience.',
    'refs': 'Romans 12:7; Acts 18:24-26'
  },
  'wisdom': {
    'name': 'Wisdom',
    'desc': 'Insight to apply scriptural truth to complex or pivotal situations in a way that honors God.',
    'refs': '1 Corinthians 12:8; James 3:17'
  },
  'intercession': {
    'name': 'Intercession',
    'desc': 'Consistent, faith-filled prayer advocacy that sees God move in specific people or causes.',
    'refs': 'Colossians 1:9-12; 1 Timothy 2:1'
  },
  'service': {
    'name': 'Service',
    'desc': 'Joyful readiness to meet practical needs that releases and supports broader ministry impact.',
    'refs': 'Romans 12:7; Acts 6:1-7'
  },
  'tongues-and-interpretation': {
    'name': 'Tongues & Interpretation',
    'desc': 'Spirit-enabled utterance and interpretive pairing that edifies when exercised orderly.',
    'refs': '1 Corinthians 12:10; 1 Corinthians 14:27-28'
  },
  'giving': {
    'name': 'Giving',
    'desc': 'Spirit-prompted generosity that resources kingdom work with unusual joy and sacrifice.',
    'refs': 'Romans 12:8; 2 Corinthians 8:1-5'
  },
  'missionary': {
    'name': 'Missionary',
    'desc': 'Capacity to effectively cross cultural or geographic barriers to advance the gospel.',
    'refs': 'Acts 13:2-4; 1 Corinthians 9:19-23'
  },
  'apostleship': {
    'name': 'Apostleship',
    'desc': 'Pioneering drive to establish new works and extend gospel influence into unreached contexts.',
    'refs': 'Ephesians 4:11; Romans 15:20'
  },
  'craftsmanship': {
    'name': 'Craftsmanship',
    'desc': 'Creative skill with materials or environments that tangibly supports ministry and worship.',
    'refs': 'Exodus 31:3-5; 1 Chronicles 28:21'
  },
  'administration': {
    'name': 'Administration',
    'desc': 'Organizational clarity to structure processes, resources, and teams for sustainable mission progress.',
    'refs': '1 Corinthians 12:28; Titus 1:5'
  },
  'music-worship': {
    'name': 'Music/Worship',
    'desc': 'Spirit-led ability to facilitate corporate or personal worship through musical gifting.',
    'refs': '1 Chronicles 25:1-7; Colossians 3:16'
  },
};
