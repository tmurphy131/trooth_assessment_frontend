/// Weekly Tips Data for Apprentices
/// 52 tips - one for each week of the year

class ApprenticeWeeklyTip {
  final int weekNumber;
  final String title;
  final String content;
  final String? scripture;
  final String? actionStep;

  const ApprenticeWeeklyTip({
    required this.weekNumber,
    required this.title,
    required this.content,
    this.scripture,
    this.actionStep,
  });
}

/// Get the current week number (1-52)
int getApprenticeCurrentWeekNumber() {
  final now = DateTime.now();
  final firstDayOfYear = DateTime(now.year, 1, 1);
  final daysDifference = now.difference(firstDayOfYear).inDays;
  return ((daysDifference / 7).floor() % 52) + 1;
}

/// Get the tip for the current week
ApprenticeWeeklyTip getApprenticeCurrentWeekTip() {
  final weekNumber = getApprenticeCurrentWeekNumber();
  return apprenticeWeeklyTips.firstWhere(
    (tip) => tip.weekNumber == weekNumber,
    orElse: () => apprenticeWeeklyTips.first,
  );
}

/// Get tip by week number
ApprenticeWeeklyTip? getApprenticeTipByWeek(int weekNumber) {
  try {
    return apprenticeWeeklyTips.firstWhere((tip) => tip.weekNumber == weekNumber);
  } catch (e) {
    return null;
  }
}

/// All 52 weekly tips for apprentices
const List<ApprenticeWeeklyTip> apprenticeWeeklyTips = [
  // Q1: Weeks 1-13 - Foundations
  ApprenticeWeeklyTip(
    weekNumber: 1,
    title: 'Show Up Consistently',
    content: '''The most important thing you can do in mentorship is simply show up. Be there. On time. Ready.

Consistency builds trust. It shows your mentor that you value their time and the relationship. Even when you don't feel like it, showing up is half the battle.''',
    scripture: 'Hebrews 10:25 - "Not giving up meeting together, as some are in the habit of doing, but encouraging one another."',
    actionStep: 'Set a recurring reminder for your mentoring meetings. Treat them like unmovable appointments.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 2,
    title: 'Come with Questions',
    content: '''Your mentor wants to help, but they need to know what you're wrestling with. Don't wait for them to guess.

Before each meeting, write down at least one question or topic you want to discuss. It could be about faith, life, relationships, or decisions you're facing.''',
    scripture: 'Proverbs 2:3-5 - "If you call out for insight and cry aloud for understanding... then you will find the knowledge of God."',
    actionStep: 'Keep a running list of questions on your phone. Add to it whenever something comes up during the week.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 3,
    title: 'Be Honest About Struggles',
    content: '''Your mentor isn't there to judge you—they're there to help you grow. But they can't help with what they don't know.

It's scary to share struggles, but that's where the real growth happens. Your mentor has probably faced similar things. Let them in.''',
    scripture: 'James 5:16 - "Therefore confess your sins to each other and pray for each other so that you may be healed."',
    actionStep: "Share one struggle with your mentor this week that you haven't talked about before.",
  ),
  ApprenticeWeeklyTip(
    weekNumber: 4,
    title: 'Follow Through',
    content: '''When you commit to doing something—reading a chapter, trying a practice, making a change—actually do it.

Following through shows integrity. It also accelerates your growth. The things your mentor suggests aren't random; they're meant to help you grow.''',
    scripture: 'Matthew 5:37 - "Let your yes be yes, and your no be no."',
    actionStep: "Whatever you committed to last time, make sure it's done before your next meeting.",
  ),
  ApprenticeWeeklyTip(
    weekNumber: 5,
    title: 'Start Your Day with God',
    content: '''How you start your day shapes the rest of it. Before screens, before noise—give God the first moments.

Even 5 minutes can make a difference. Read a verse. Pray. Sit quietly. Starting with God sets the tone for everything else.''',
    scripture: 'Psalm 5:3 - "In the morning, Lord, you hear my voice; in the morning I lay my requests before you and wait expectantly."',
    actionStep: 'This week, spend 5 minutes with God each morning before you check your phone.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 6,
    title: 'Write It Down',
    content: '''Keep a journal of what you're learning in mentorship. Write down insights, questions, verses, and things you want to remember.

Writing helps you process and retain what you're learning. You'll be amazed looking back at how much you've grown.''',
    scripture: 'Habakkuk 2:2 - "Write down the revelation and make it plain."',
    actionStep: 'Get a notebook or start a notes page just for your mentoring journey.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 7,
    title: 'Embrace Discomfort',
    content: '''Growth happens outside your comfort zone. When something feels uncomfortable—that might be exactly where you need to lean in.

Your mentor will challenge you. It's not to make you feel bad; it's to help you grow. Lean into the discomfort.''',
    scripture: 'Romans 5:3-4 - "We also glory in our sufferings, because we know that suffering produces perseverance; perseverance, character."',
    actionStep: 'This week, do one thing that pushes you out of your comfort zone spiritually.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 8,
    title: 'Celebrate Small Wins',
    content: '''Growth is often slow and invisible. Take time to notice and celebrate the small victories.

Did you pray when you normally wouldn't? Did you respond better in conflict? Did you show up when you wanted to stay home? That's growth. Celebrate it.''',
    scripture: 'Zechariah 4:10 - "Do not despise these small beginnings, for the Lord rejoices to see the work begin."',
    actionStep: 'Share one small win with your mentor this week.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 9,
    title: 'Practice Gratitude',
    content: '''Gratitude changes everything. It shifts your focus from what's missing to what's present. It combats anxiety and builds joy.

Start and end your day by naming three things you're thankful for. Watch your perspective shift.''',
    scripture: '1 Thessalonians 5:18 - "Give thanks in all circumstances; for this is God\'s will for you in Christ Jesus."',
    actionStep: 'Each night this week, write down three things you\'re grateful for.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 10,
    title: 'Guard Your Inputs',
    content: '''What you consume shapes who you become. Social media, music, shows, podcasts—they all influence your mind and heart.

Be intentional about what you let in. Not everything is bad, but not everything is helpful. Choose wisely.''',
    scripture: 'Philippians 4:8 - "Whatever is true, whatever is noble, whatever is right... think about such things."',
    actionStep: 'Audit your media diet this week. Is what you\'re consuming helping or hurting your growth?',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 11,
    title: 'Learn to Wait',
    content: '''Our culture hates waiting. But some of God's best work happens in the waiting. Patience is a spiritual muscle.

When you don't have answers, when things aren't happening fast enough—trust the process. God is at work even when you can't see it.''',
    scripture: 'Isaiah 40:31 - "Those who wait on the Lord shall renew their strength."',
    actionStep: 'Identify one area where you\'re impatient. Ask God to help you trust His timing.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 12,
    title: 'Find Your Tribe',
    content: '''You weren't meant to follow Jesus alone. You need community—people who will encourage, challenge, and walk with you.

Your mentor is part of this, but so is church, small groups, and Christian friends. Invest in community.''',
    scripture: 'Ecclesiastes 4:9-10 - "Two are better than one... If either of them falls down, one can help the other up."',
    actionStep: 'If you\'re not in a small group or community, talk with your mentor about finding one.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 13,
    title: 'Rest Is Holy',
    content: '''Rest isn't laziness—it's obedience. God rested. He commanded Sabbath. You were designed to stop and recharge.

In a culture of constant hustle, rest is countercultural. But it's essential for your soul.''',
    scripture: 'Mark 2:27 - "The Sabbath was made for man, not man for the Sabbath."',
    actionStep: 'Schedule intentional rest this week. Not just sleep—soul rest.',
  ),

  // Q2: Weeks 14-26 - Growing Deeper
  ApprenticeWeeklyTip(
    weekNumber: 14,
    title: 'Memorize Scripture',
    content: '''Having God's Word in your mind changes how you think. When you memorize Scripture, it's there when you need it most.

Start small. One verse a week. Over a year, that's 52 verses hidden in your heart.''',
    scripture: 'Psalm 119:11 - "I have hidden your word in my heart that I might not sin against you."',
    actionStep: 'Choose one verse to memorize this week. Write it on a note card and review it daily.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 15,
    title: 'Pray Specifically',
    content: '''Vague prayers get vague answers. Be specific when you pray. Tell God exactly what you need, fear, hope for, and want.

Specific prayers also help you see God's answers more clearly. You'll notice when He moves.''',
    scripture: 'Philippians 4:6 - "In every situation, by prayer and petition, with thanksgiving, present your requests to God."',
    actionStep: 'Write out five specific prayer requests. Pray them daily and watch for God\'s response.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 16,
    title: 'Confession Brings Freedom',
    content: '''Sin thrives in secrecy. When you confess—to God and to trusted people—you bring it into the light where it loses its power.

Confession isn't about shame. It's about freedom. Let go of what you're carrying.''',
    scripture: '1 John 1:9 - "If we confess our sins, he is faithful and just and will forgive us our sins."',
    actionStep: 'Is there something you need to confess? Bring it to God and consider sharing it with your mentor.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 17,
    title: 'Learn from Failure',
    content: '''Failure isn't the opposite of success—it's part of the path to it. Every failure is data. Every mistake teaches something.

Don't let failure define you or stop you. Let it teach you and make you better.''',
    scripture: 'Proverbs 24:16 - "For though the righteous fall seven times, they rise again."',
    actionStep: 'Think of a recent failure. What did it teach you? Share the lesson with your mentor.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 18,
    title: 'Serve Someone',
    content: '''Faith isn't just believed—it's lived. Serving others is one of the clearest expressions of following Jesus.

Look for someone to serve this week. Not for recognition, but because you've been served by Christ.''',
    scripture: 'Mark 10:45 - "For even the Son of Man did not come to be served, but to serve."',
    actionStep: 'Do one act of service this week that no one will see or thank you for.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 19,
    title: 'Forgive Quickly',
    content: '''Unforgiveness is a poison you drink hoping the other person will get sick. It only hurts you.

Forgiveness doesn't mean what happened was okay. It means you're releasing the debt. It's freedom for you.''',
    scripture: 'Ephesians 4:32 - "Be kind and compassionate to one another, forgiving each other, just as in Christ God forgave you."',
    actionStep: 'Is there anyone you need to forgive? Take a step toward releasing that today.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 20,
    title: 'Fight Comparison',
    content: '''Comparison is the thief of joy. Social media makes it worse. Everyone else\'s highlight reel vs. your behind-the-scenes isn\'t a fair fight.

You\'re on your own journey. Focus on your growth, not others\' appearances.''',
    scripture: 'Galatians 6:4 - "Each one should test their own actions. Then they can take pride in themselves alone, without comparing themselves to someone else."',
    actionStep: 'When you catch yourself comparing this week, pause and thank God for something specific about YOUR journey.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 21,
    title: 'Embrace Silence',
    content: '''We're surrounded by noise. Constant input. Learning to be silent before God is a lost art—and a powerful one.

In silence, you can hear what the noise drowns out. God often speaks in the stillness.''',
    scripture: 'Psalm 46:10 - "Be still, and know that I am God."',
    actionStep: 'Spend 10 minutes in complete silence this week. No music, no phone. Just you and God.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 22,
    title: 'Your Words Matter',
    content: '''Words have power. They can build up or tear down. They can heal or wound. Be careful with what comes out of your mouth.

Before you speak, ask: Is it true? Is it helpful? Is it kind?''',
    scripture: 'Proverbs 18:21 - "The tongue has the power of life and death."',
    actionStep: 'Pay attention to your words this week. Notice patterns. Are they building up or tearing down?',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 23,
    title: 'Doubt Is Not the Enemy',
    content: '''Doubt doesn't mean you're failing at faith. Some of the greatest believers wrestled with doubt. It's part of the journey.

The opposite of faith isn't doubt—it's certainty that doesn't need God. Bring your doubts to Him.''',
    scripture: 'Mark 9:24 - "I do believe; help me overcome my unbelief!"',
    actionStep: 'If you have doubts, share them with your mentor. Don\'t let them fester in silence.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 24,
    title: 'Choose Your Influences',
    content: '''You become like the people you spend the most time with. Choose influences that pull you toward who you want to become.

This doesn\'t mean ditching friends who aren\'t Christians. But be intentional about who shapes you most.''',
    scripture: '1 Corinthians 15:33 - "Bad company corrupts good character."',
    actionStep: 'Think about your five closest influences. Are they pulling you toward or away from Christ?',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 25,
    title: 'Give Generously',
    content: '''Generosity isn\'t about having a lot—it\'s about holding loosely what you have. Start giving now, whatever your income.

Generosity breaks the grip of money and reflects the heart of a generous God.''',
    scripture: '2 Corinthians 9:7 - "God loves a cheerful giver."',
    actionStep: 'Give something this week—money, time, or resources. Do it cheerfully.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 26,
    title: 'Check Your Heart',
    content: '''It\'s possible to do all the right things for all the wrong reasons. Don\'t just check your behavior—check your heart.

Why are you doing what you\'re doing? What\'s really motivating you?''',
    scripture: 'Proverbs 4:23 - "Above all else, guard your heart, for everything you do flows from it."',
    actionStep: 'Ask God to search your heart this week. What motives need adjusting?',
  ),

  // Q3: Weeks 27-39 - Living It Out
  ApprenticeWeeklyTip(
    weekNumber: 27,
    title: 'Be the Same Everywhere',
    content: '''Integrity means being the same person in every room. Who you are at church should match who you are at school, at home, online.

Compartmentalized faith isn\'t real faith. Let Jesus be Lord of all your life, not just parts of it.''',
    scripture: 'Proverbs 10:9 - "Whoever walks in integrity walks securely."',
    actionStep: 'Is there any area of your life where you\'re a different person? What would integrity look like there?',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 28,
    title: 'Handle Conflict Well',
    content: '''Conflict is inevitable. How you handle it determines whether it destroys or strengthens relationships.

Go directly to the person. Don\'t gossip. Listen first. Seek to understand. Be quick to apologize.''',
    scripture: 'Matthew 18:15 - "If your brother or sister sins, go and point out their fault, just between the two of you."',
    actionStep: 'Is there a conflict you\'ve been avoiding? Take a step toward resolving it this week.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 29,
    title: 'Protect Your Purity',
    content: '''Purity isn\'t just about sex—it\'s about what you let into your mind and heart. In a world that normalizes impurity, this is countercultural.

Set boundaries now. They\'re easier to keep than to rebuild after they\'re broken.''',
    scripture: 'Psalm 119:9 - "How can a young person stay on the path of purity? By living according to your word."',
    actionStep: 'What boundaries do you need to set or strengthen to protect your purity?',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 30,
    title: 'Tell Your Story',
    content: '''Your story matters. What God has done in your life is a powerful testimony. Don\'t hide it.

You don\'t have to have a dramatic story. Transformation is transformation. Share what God has done.''',
    scripture: 'Psalm 107:2 - "Let the redeemed of the Lord tell their story."',
    actionStep: 'Practice telling your faith story in 3 minutes. Share it with your mentor.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 31,
    title: 'Worship Beyond Sunday',
    content: '''Worship isn\'t just singing at church. It\'s a lifestyle. Your whole life can be an act of worship.

How you work, how you treat people, how you spend your time—all of it can honor God.''',
    scripture: 'Romans 12:1 - "Offer your bodies as a living sacrifice, holy and pleasing to God—this is your true and proper worship."',
    actionStep: 'Identify one everyday activity and intentionally do it as worship this week.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 32,
    title: 'Trust the Process',
    content: '''Transformation doesn\'t happen overnight. It\'s a process—often slow, sometimes painful, always worth it.

You won\'t be the same person in a year. Trust that God is at work even when you can\'t see progress.''',
    scripture: 'Philippians 1:6 - "He who began a good work in you will carry it on to completion."',
    actionStep: 'Look back at where you were a year ago. Thank God for the progress you might not notice day-to-day.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 33,
    title: 'Take Thoughts Captive',
    content: '''Your thoughts shape your feelings and actions. Not every thought deserves a seat at the table. Learn to evaluate and reject lies.

When a thought doesn\'t align with God\'s truth, replace it with what\'s true.''',
    scripture: '2 Corinthians 10:5 - "We take captive every thought to make it obedient to Christ."',
    actionStep: 'Identify one recurring negative thought. Find a verse that counters it. Use it as a weapon.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 34,
    title: 'Don\'t Go It Alone',
    content: '''Independence is overrated. You need people who know your struggles and have permission to call you out.

Find accountability—whether that\'s your mentor, a friend, or a group. Let people in.''',
    scripture: 'Proverbs 27:17 - "As iron sharpens iron, so one person sharpens another."',
    actionStep: 'Who has permission to ask you hard questions? If no one, ask someone to be that for you.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 35,
    title: 'Use Your Gifts',
    content: '''God has given you unique gifts for a purpose—not to hide, but to use for His kingdom and others\' good.

Discover your gifts and deploy them. The body of Christ needs what you bring.''',
    scripture: '1 Peter 4:10 - "Each of you should use whatever gift you have received to serve others."',
    actionStep: 'Talk with your mentor about your spiritual gifts. How can you use them more?',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 36,
    title: 'Love the Hard People',
    content: '''It\'s easy to love people who love you back. The test of love is loving those who are difficult.

That annoying person? Love them. That person who wronged you? Love them. This is Jesus\' way.''',
    scripture: 'Matthew 5:44 - "Love your enemies and pray for those who persecute you."',
    actionStep: 'Identify one difficult person. Pray for them and find one way to show them kindness this week.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 37,
    title: 'Stay Humble',
    content: '''Pride is sneaky. It creeps in when things are going well. It compares and looks down. It\'s the enemy of growth.

Stay humble. Remember where you came from. Recognize everything good is from God.''',
    scripture: 'James 4:6 - "God opposes the proud but shows favor to the humble."',
    actionStep: 'Ask God to reveal any pride in your life. Ask a trusted person if they see it.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 38,
    title: 'Run Your Race',
    content: '''Life isn\'t a sprint—it\'s a marathon. Pace yourself. Don\'t burn out trying to do everything now.

You\'re not competing with others. You\'re running your own race. Stay focused on your lane.''',
    scripture: 'Hebrews 12:1 - "Let us run with perseverance the race marked out for us."',
    actionStep: 'Are you trying to sprint when you should be pacing? What do you need to let go of to run well?',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 39,
    title: 'Keep Showing Up',
    content: '''Some days you won\'t feel it. Faith will feel dry. Growth will feel slow. Show up anyway.

Consistency in the mundane is where character is built. Don\'t let feelings dictate faithfulness.''',
    scripture: 'Galatians 6:9 - "Let us not become weary in doing good, for at the proper time we will reap a harvest if we do not give up."',
    actionStep: 'Is there something you\'ve been inconsistent with? Recommit to showing up.',
  ),

  // Q4: Weeks 40-52 - Finishing Strong
  ApprenticeWeeklyTip(
    weekNumber: 40,
    title: 'Look for God\'s Hand',
    content: '''God is always at work—you just have to look. Train yourself to see His fingerprints in your life.

When you start looking, you\'ll be amazed at how active He is, even in small things.''',
    scripture: 'Psalm 105:1 - "Give praise to the Lord, proclaim his name; make known among the nations what he has done."',
    actionStep: 'Start noticing. Write down three ways you saw God at work this week.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 41,
    title: 'Finish What You Start',
    content: '''It\'s easy to start things. Finishing is harder. But there\'s something powerful about completing what you began.

Look at your commitments. What have you left unfinished? What needs to be completed?''',
    scripture: '2 Timothy 4:7 - "I have fought the good fight, I have finished the race, I have kept the faith."',
    actionStep: 'Identify one thing you\'ve left undone. Make a plan to finish it.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 42,
    title: 'Invest in Eternity',
    content: '''Most of what we chase is temporary. Money, status, possessions—they don\'t last. What lasts forever?

People last. Faith lasts. Character lasts. Invest your time and energy in things with eternal value.''',
    scripture: 'Matthew 6:20 - "Store up for yourselves treasures in heaven."',
    actionStep: 'What are you investing in that won\'t last? What eternal investment could you make this week?',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 43,
    title: 'Stay Curious',
    content: '''Never stop learning. About God, about life, about yourself. Curiosity keeps faith fresh and growth going.

Ask questions. Read. Listen to people with different perspectives. Stay a student.''',
    scripture: 'Proverbs 18:15 - "The heart of the discerning acquires knowledge, for the ears of the wise seek it out."',
    actionStep: 'What\'s something you\'re curious about spiritually? Ask your mentor or start exploring it.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 44,
    title: 'Build Daily Rhythms',
    content: '''Spiritual growth doesn\'t happen by accident. It happens through intentional rhythms—daily practices that shape your soul.

What does your daily rhythm look like? Is there space for God?''',
    scripture: 'Daniel 6:10 - "Three times a day he got down on his knees and prayed."',
    actionStep: 'Evaluate your daily rhythm. What one practice could you add or strengthen?',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 45,
    title: 'Say Thank You',
    content: '''Gratitude to others matters. Your mentor is investing time in you. Your parents sacrifice for you. Friends show up for you.

Don\'t let kindness go unacknowledged. Say thank you—specifically and often.''',
    scripture: 'Colossians 3:15 - "Be thankful."',
    actionStep: 'Write a thank you note to your mentor. Tell them specifically what their investment has meant.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 46,
    title: 'Let Go of Perfection',
    content: '''Perfectionism isn\'t excellence—it\'s fear. Fear of failure, fear of judgment, fear of not being enough.

You don\'t have to be perfect. Jesus already did that for you. Embrace grace.''',
    scripture: '2 Corinthians 12:9 - "My grace is sufficient for you, for my power is made perfect in weakness."',
    actionStep: 'Where is perfectionism holding you back? What would grace look like in that area?',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 47,
    title: 'Prepare for Hard Times',
    content: '''Hard times will come. Not if—when. The question is whether you\'ll be prepared or caught off guard.

Build reserves now—spiritual disciplines, community, truth in your heart—for when the storm comes.''',
    scripture: 'Matthew 7:25 - "The rain came down, the streams rose... yet it did not fall, because it had its foundation on the rock."',
    actionStep: 'What spiritual reserves are you building? What\'s one thing you can do now to prepare for future storms?',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 48,
    title: 'Share What You\'re Learning',
    content: '''The best way to learn something is to teach it. Share what you\'re learning with someone else.

You don\'t have to be an expert. Just pass along what God is teaching you.''',
    scripture: '2 Timothy 2:2 - "The things you have heard me say... entrust to reliable people who will also be qualified to teach others."',
    actionStep: 'Share one thing you\'ve learned in mentorship with a friend this week.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 49,
    title: 'Dream Big Dreams',
    content: '''God is bigger than your biggest dreams. Don\'t limit what He might do in and through your life.

What would you attempt if you knew you couldn\'t fail? Dream with God about your future.''',
    scripture: 'Ephesians 3:20 - "God is able to do immeasurably more than all we ask or imagine."',
    actionStep: 'Write down a God-sized dream for your life. Share it with your mentor.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 50,
    title: 'Celebrate Progress',
    content: '''How far have you come this year? Don\'t just look at what\'s left to do—celebrate what God has already done.

Progress deserves recognition. Growth deserves celebration. Thank God for how far you\'ve come.''',
    scripture: 'Psalm 126:3 - "The Lord has done great things for us, and we are filled with joy."',
    actionStep: 'Make a list of ways you\'ve grown this year. Celebrate them with your mentor.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 51,
    title: 'Set Goals for Growth',
    content: '''A new year is a fresh start. What do you want to be different a year from now?

Set specific, measurable goals for your spiritual growth. Write them down. Share them. Pursue them.''',
    scripture: 'Proverbs 21:5 - "The plans of the diligent lead to profit."',
    actionStep: 'Write three spiritual growth goals for the coming year. Discuss them with your mentor.',
  ),
  ApprenticeWeeklyTip(
    weekNumber: 52,
    title: 'Keep Going',
    content: '''One year down, a lifetime to go. The journey of faith never ends this side of heaven.

Whatever next year holds—keep going. Keep showing up. Keep growing. Keep following Jesus.''',
    scripture: 'Philippians 3:14 - "I press on toward the goal to win the prize for which God has called me heavenward in Christ Jesus."',
    actionStep: 'Reflect on this year with your mentor. Commit to continued growth together or in new ways.',
  ),
];
