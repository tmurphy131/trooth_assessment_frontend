/// Weekly Tips Data for Mentors
/// 52 tips - one for each week of the year

class WeeklyTip {
  final int weekNumber;
  final String title;
  final String content;
  final String? scripture;
  final String? actionStep;

  const WeeklyTip({
    required this.weekNumber,
    required this.title,
    required this.content,
    this.scripture,
    this.actionStep,
  });
}

/// Get the current week number (1-52)
int getCurrentWeekNumber() {
  final now = DateTime.now();
  final firstDayOfYear = DateTime(now.year, 1, 1);
  final daysDifference = now.difference(firstDayOfYear).inDays;
  return ((daysDifference / 7).floor() % 52) + 1;
}

/// Get the tip for the current week
WeeklyTip getCurrentWeekTip() {
  final weekNumber = getCurrentWeekNumber();
  return weeklyTips.firstWhere(
    (tip) => tip.weekNumber == weekNumber,
    orElse: () => weeklyTips.first,
  );
}

/// Get tip by week number
WeeklyTip? getTipByWeek(int weekNumber) {
  try {
    return weeklyTips.firstWhere((tip) => tip.weekNumber == weekNumber);
  } catch (e) {
    return null;
  }
}

/// All 52 weekly tips
const List<WeeklyTip> weeklyTips = [
  // Q1: Weeks 1-13 - Building Foundation
  WeeklyTip(
    weekNumber: 1,
    title: 'Start with Prayer',
    content: '''Begin each mentoring session by praying together. This sets the tone for your time and invites God into your conversation.

Prayer doesn't need to be long or formal. A simple "Lord, guide our conversation today" can be powerful. It reminds both of you that this relationship is grounded in something greater than yourselves.''',
    scripture: 'Philippians 4:6 - "Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God."',
    actionStep: 'At your next meeting, ask your apprentice if you can open in prayer together.',
  ),
  WeeklyTip(
    weekNumber: 2,
    title: 'Listen More Than You Speak',
    content: '''Your apprentice needs to be heard before they need advice. Active listening shows respect and helps you truly understand their situation.

Practice the 80/20 rule: aim to listen 80% of the time and speak only 20%. When you do speak, ask clarifying questions rather than jumping to solutions.''',
    scripture: 'James 1:19 - "Everyone should be quick to listen, slow to speak and slow to become angry."',
    actionStep: 'In your next conversation, consciously count to three before responding to give yourself time to fully hear.',
  ),
  WeeklyTip(
    weekNumber: 3,
    title: 'Ask "How Can I Help?"',
    content: '''Sometimes the best guidance comes from asking what your apprentice actually needs. Don't assume you know what they're looking for.

This simple question empowers them to articulate their needs and ensures your support is relevant. It also respects their autonomy and builds trust.''',
    scripture: 'Mark 10:51 - "What do you want me to do for you?" Jesus asked him.',
    actionStep: 'Start your next meeting by asking "What would be most helpful to discuss today?"',
  ),
  WeeklyTip(
    weekNumber: 4,
    title: 'Share Your Struggles',
    content: '''Vulnerability builds trust. Share a time when you faced similar challenges to what your apprentice is experiencing.

You don't need to have all the answers. Sometimes the most powerful thing you can say is "I've been there too." It normalizes their struggles and shows growth is possible.''',
    scripture: '2 Corinthians 1:4 - "...so that we can comfort those in any trouble with the comfort we ourselves receive from God."',
    actionStep: 'Think of one struggle from your past that might encourage your apprentice, and share it appropriately.',
  ),
  WeeklyTip(
    weekNumber: 5,
    title: 'Celebrate Small Wins',
    content: '''Progress isn't always dramatic. Notice the small steps your apprentice takes and call them out.

A simple "I noticed you handled that differently than before" or "That took courage" can be incredibly affirming. Celebration fuels motivation to keep growing.''',
    scripture: 'Zechariah 4:10 - "Do not despise these small beginnings, for the Lord rejoices to see the work begin."',
    actionStep: 'Identify one small win from your apprentice this week and send them an encouraging message about it.',
  ),
  WeeklyTip(
    weekNumber: 6,
    title: 'Be Consistent',
    content: '''Show up reliably. Consistency builds trust more than occasional grand gestures.

If you say you'll meet every Tuesday at 7pm, protect that time. If you need to reschedule, do so promptly. Your reliability teaches them that they matter.''',
    scripture: '1 Corinthians 4:2 - "Now it is required that those who have been given a trust must prove faithful."',
    actionStep: 'Review your meeting schedule - are there any sessions you\'ve missed or rescheduled frequently? Recommit to consistency.',
  ),
  WeeklyTip(
    weekNumber: 7,
    title: 'Ask Open-Ended Questions',
    content: '''Questions that can't be answered with yes or no invite deeper conversation. They show genuine curiosity and help your apprentice think through issues.

Instead of "Did that make you angry?" try "How did that situation make you feel?" The difference opens doors to meaningful dialogue.''',
    scripture: 'Proverbs 20:5 - "The purposes of a person\'s heart are deep waters, but one who has insight draws them out."',
    actionStep: 'Prepare 3 open-ended questions before your next meeting.',
  ),
  WeeklyTip(
    weekNumber: 8,
    title: 'Practice Patience',
    content: '''Growth takes time. Your apprentice won't change overnight, and that's okay.

Resist the urge to rush them or show frustration when progress seems slow. Remember your own journey - transformation is rarely linear.''',
    scripture: 'Galatians 6:9 - "Let us not become weary in doing good, for at the proper time we will reap a harvest if we do not give up."',
    actionStep: 'Reflect on your own spiritual growth journey. How long did lasting change take for you?',
  ),
  WeeklyTip(
    weekNumber: 9,
    title: 'Set Clear Expectations',
    content: '''Unclear expectations lead to frustration. Make sure you and your apprentice are aligned on meeting frequency, communication, and goals.

Having this conversation early prevents misunderstandings later. It's okay to revisit and adjust expectations as your relationship develops.''',
    scripture: 'Amos 3:3 - "Do two walk together unless they have agreed to do so?"',
    actionStep: 'If you haven\'t already, have a conversation about expectations with your apprentice.',
  ),
  WeeklyTip(
    weekNumber: 10,
    title: 'Encourage Scripture Reading',
    content: '''God's Word is the ultimate source of wisdom. Encourage your apprentice to spend time in Scripture regularly.

Consider reading the same passage during the week and discussing it together. This creates shared spiritual ground and models the importance of Bible study.''',
    scripture: 'Psalm 119:105 - "Your word is a lamp for my feet, a light on my path."',
    actionStep: 'Suggest a passage for both of you to read before your next meeting.',
  ),
  WeeklyTip(
    weekNumber: 11,
    title: 'Respect Boundaries',
    content: '''Healthy boundaries protect both you and your apprentice. Know when to step back and when to step in.

You're a mentor, not a therapist or crisis counselor. It's okay to say "This might be beyond what I can help with - have you considered talking to a professional?"''',
    scripture: 'Proverbs 4:23 - "Above all else, guard your heart, for everything you do flows from it."',
    actionStep: 'Reflect on whether any boundaries need to be clarified in your mentoring relationship.',
  ),
  WeeklyTip(
    weekNumber: 12,
    title: 'Model What You Teach',
    content: '''Your life is your most powerful lesson. Your apprentice is watching how you handle challenges, relationships, and faith.

This isn't about being perfect - it's about being authentic. When you stumble, let them see how you recover and return to God.''',
    scripture: '1 Corinthians 11:1 - "Follow my example, as I follow the example of Christ."',
    actionStep: 'Consider what aspect of your life is currently modeling faith well. What area needs work?',
  ),
  WeeklyTip(
    weekNumber: 13,
    title: 'Check Your Motives',
    content: '''Why are you mentoring? The best mentors are motivated by genuine love for their apprentice and desire to glorify God.

If you find yourself seeking recognition, control, or validation, pause and recenter. Mentoring is about serving, not being served.''',
    scripture: 'Philippians 2:3 - "Do nothing out of selfish ambition or vain conceit. Rather, in humility value others above yourselves."',
    actionStep: 'Take a few minutes to honestly examine your motivations for mentoring.',
  ),

  // Q2: Weeks 14-26 - Growing Deeper
  WeeklyTip(
    weekNumber: 14,
    title: 'Embrace Silence',
    content: '''Not every pause needs to be filled. Sometimes silence gives your apprentice space to think and process.

Resist the urge to jump in when there's quiet. Some of the most meaningful insights come after a moment of reflection.''',
    scripture: 'Ecclesiastes 3:7 - "...a time to be silent and a time to speak."',
    actionStep: 'Practice being comfortable with 10 seconds of silence in your next conversation.',
  ),
  WeeklyTip(
    weekNumber: 15,
    title: 'Address the Heart',
    content: '''Behavior change follows heart change. Help your apprentice examine the "why" behind their actions, not just the "what."

Surface-level advice addresses symptoms. Going deeper to values, beliefs, and motivations creates lasting transformation.''',
    scripture: 'Proverbs 4:23 - "Above all else, guard your heart, for everything you do flows from it."',
    actionStep: 'When an issue comes up, ask "What do you think is really going on underneath this?"',
  ),
  WeeklyTip(
    weekNumber: 16,
    title: 'Encourage Community',
    content: '''Mentoring shouldn't happen in isolation. Encourage your apprentice to be connected to a church community and other believers.

You can't meet all their needs, and you shouldn't try. A healthy network of relationships supports lasting growth.''',
    scripture: 'Hebrews 10:24-25 - "And let us consider how we may spur one another on toward love and good deeds, not giving up meeting together."',
    actionStep: 'Ask your apprentice about their church involvement and other supportive relationships.',
  ),
  WeeklyTip(
    weekNumber: 17,
    title: 'Give Honest Feedback',
    content: '''Speaking truth in love is a gift. Your apprentice needs honest feedback, not just encouragement.

Deliver difficult truths with compassion and timing. Ask permission before giving feedback: "Can I share an observation?"''',
    scripture: 'Proverbs 27:6 - "Wounds from a friend can be trusted, but an enemy multiplies kisses."',
    actionStep: 'Is there something you\'ve been hesitant to address? Prayerfully consider how to bring it up.',
  ),
  WeeklyTip(
    weekNumber: 18,
    title: 'Learn Their Story',
    content: '''Understanding your apprentice's background helps you mentor them well. Their past shapes how they see themselves and God.

Take time to learn about their family, formative experiences, and faith journey. This context makes your guidance more relevant.''',
    scripture: 'Proverbs 20:5 - "The purposes of a person\'s heart are deep waters, but one who has insight draws them out."',
    actionStep: 'Ask your apprentice to share a meaningful story from their childhood.',
  ),
  WeeklyTip(
    weekNumber: 19,
    title: 'Pray Specifically',
    content: '''Generic prayers are fine, but specific prayers show you're paying attention. Pray for the exact situations your apprentice is facing.

Keep notes on prayer requests and follow up. "How did that job interview go?" shows you genuinely care.''',
    scripture: 'Matthew 7:7 - "Ask and it will be given to you; seek and you will find; knock and the door will be opened to you."',
    actionStep: 'Write down 3 specific things to pray for your apprentice this week.',
  ),
  WeeklyTip(
    weekNumber: 20,
    title: 'Challenge Comfort Zones',
    content: '''Growth happens at the edge of comfort. Gently push your apprentice to try new things and face fears.

This could be serving in a new ministry, having a difficult conversation, or stepping into leadership. Be their encourager as they stretch.''',
    scripture: 'Joshua 1:9 - "Have I not commanded you? Be strong and courageous. Do not be afraid; do not be discouraged, for the Lord your God will be with you wherever you go."',
    actionStep: 'Identify one area where your apprentice might benefit from a gentle push.',
  ),
  WeeklyTip(
    weekNumber: 21,
    title: 'Admit When You\'re Wrong',
    content: '''You will make mistakes. When you do, own them quickly and sincerely.

Apologizing models humility and shows your apprentice that integrity matters more than image. It also builds trust.''',
    scripture: 'James 5:16 - "Therefore confess your sins to each other and pray for each other so that you may be healed."',
    actionStep: 'If there\'s an unaddressed mistake, consider addressing it with your apprentice.',
  ),
  WeeklyTip(
    weekNumber: 22,
    title: 'Focus on Progress, Not Perfection',
    content: '''Your apprentice will never be perfect, and neither will you. Celebrate progress and extend grace for setbacks.

Perfectionism leads to shame and hiding. A grace-filled environment encourages honesty and continued effort.''',
    scripture: 'Philippians 1:6 - "Being confident of this, that he who began a good work in you will carry it on to completion until the day of Christ Jesus."',
    actionStep: 'Remind your apprentice of progress they\'ve made since you started meeting.',
  ),
  WeeklyTip(
    weekNumber: 23,
    title: 'Use Stories and Examples',
    content: '''Stories stick better than lectures. When making a point, illustrate it with a real example from your life or others.

Jesus taught in parables for a reason. A well-told story can communicate truth in memorable, applicable ways.''',
    scripture: 'Mark 4:33 - "With many similar parables Jesus spoke the word to them, as much as they could understand."',
    actionStep: 'Think of a story from your life that illustrates a lesson your apprentice needs.',
  ),
  WeeklyTip(
    weekNumber: 24,
    title: 'Encourage Journaling',
    content: '''Writing helps process thoughts and track growth. Encourage your apprentice to keep a journal.

They might journal prayers, reflections, or things they're learning. Looking back months later reveals growth that's easy to miss day-to-day.''',
    scripture: 'Habakkuk 2:2 - "Write down the revelation and make it plain on tablets so that a herald may run with it."',
    actionStep: 'Suggest your apprentice try journaling for a week and discuss what they noticed.',
  ),
  WeeklyTip(
    weekNumber: 25,
    title: 'Create Accountability',
    content: '''Accountability helps your apprentice follow through on commitments. Ask about specific action steps they've set.

Be consistent but not harsh. Accountability works best when it's clear, kind, and focused on growth rather than guilt.''',
    scripture: 'Proverbs 27:17 - "As iron sharpens iron, so one person sharpens another."',
    actionStep: 'Establish a specific accountability question for something your apprentice is working on.',
  ),
  WeeklyTip(
    weekNumber: 26,
    title: 'Take a Mid-Year Check',
    content: '''Halfway through the year is a great time to reflect. How has your apprentice grown? What goals remain?

This checkpoint prevents drift and re-energizes your relationship. Celebrate wins and reset intentions for the rest of the year.''',
    scripture: 'Lamentations 3:40 - "Let us examine our ways and test them, and let us return to the Lord."',
    actionStep: 'Schedule a mid-year review conversation with your apprentice.',
  ),

  // Q3: Weeks 27-39 - Deepening Impact
  WeeklyTip(
    weekNumber: 27,
    title: 'Discuss Spiritual Gifts',
    content: '''Help your apprentice discover and develop their spiritual gifts. Understanding how God has wired them gives direction and purpose.

Consider going through a spiritual gifts assessment together. Discuss how they can use their gifts to serve others.''',
    scripture: '1 Peter 4:10 - "Each of you should use whatever gift you have received to serve others, as faithful stewards of God\'s grace in its various forms."',
    actionStep: 'Discuss your apprentice\'s spiritual gifts assessment results.',
  ),
  WeeklyTip(
    weekNumber: 28,
    title: 'Address Doubt Honestly',
    content: '''Doubt is a normal part of faith. When your apprentice expresses doubt, don't panic or dismiss it.

Engage their questions honestly. Share your own experiences with doubt. Point them to resources that address their specific concerns.''',
    scripture: 'Jude 1:22 - "Be merciful to those who doubt."',
    actionStep: 'Create space for your apprentice to share any doubts or questions about faith.',
  ),
  WeeklyTip(
    weekNumber: 29,
    title: 'Encourage Service',
    content: '''Faith grows through action. Encourage your apprentice to serve others regularly.

Service shifts focus outward and builds character. It could be volunteering at church, helping a neighbor, or using their skills for others.''',
    scripture: 'Galatians 5:13 - "Serve one another humbly in love."',
    actionStep: 'Help your apprentice identify a specific way to serve this month.',
  ),
  WeeklyTip(
    weekNumber: 30,
    title: 'Navigate Conflict Wisely',
    content: '''Conflict is inevitable in any relationship. Teach your apprentice healthy conflict resolution skills.

Model how to address issues directly but lovingly. Avoiding conflict doesn't make it go away - it usually makes it worse.''',
    scripture: 'Matthew 18:15 - "If your brother or sister sins, go and point out their fault, just between the two of you."',
    actionStep: 'Discuss a recent conflict your apprentice faced and how they handled it.',
  ),
  WeeklyTip(
    weekNumber: 31,
    title: 'Encourage Rest',
    content: '''Burnout is real. Help your apprentice establish healthy rhythms of rest and sabbath.

God modeled rest in creation for a reason. Encourage them to protect time for renewal, not just productivity.''',
    scripture: 'Mark 6:31 - "Then, because so many people were coming and going that they did not even have a chance to eat, he said to them, \'Come with me by yourselves to a quiet place and get some rest.\'"',
    actionStep: 'Ask your apprentice about their rest patterns. Are they getting enough?',
  ),
  WeeklyTip(
    weekNumber: 32,
    title: 'Discuss Temptation',
    content: '''Everyone faces temptation. Create a safe space where your apprentice can be honest about their struggles.

Shame thrives in secrecy. When temptation is brought into the light, it loses much of its power.''',
    scripture: '1 Corinthians 10:13 - "No temptation has overtaken you except what is common to mankind. And God is faithful; he will not let you be tempted beyond what you can bear."',
    actionStep: 'If appropriate, ask your apprentice about areas where they face temptation.',
  ),
  WeeklyTip(
    weekNumber: 33,
    title: 'Develop Decision-Making Skills',
    content: '''Help your apprentice make wise decisions rather than making decisions for them. Teach the process, not just the answer.

Walk them through how to weigh options, seek counsel, pray, and discern God's leading.''',
    scripture: 'Proverbs 3:5-6 - "Trust in the Lord with all your heart and lean not on your own understanding; in all your ways submit to him, and he will make your paths straight."',
    actionStep: 'When your apprentice faces a decision, guide them through the process rather than giving the answer.',
  ),
  WeeklyTip(
    weekNumber: 34,
    title: 'Celebrate Obedience',
    content: '''When your apprentice obeys God in difficult circumstances, make a big deal of it. Obedience often goes unnoticed.

Acknowledging faithful choices reinforces them and builds courage for future decisions.''',
    scripture: '1 Samuel 15:22 - "To obey is better than sacrifice."',
    actionStep: 'Look for an instance of obedience in your apprentice\'s life to celebrate.',
  ),
  WeeklyTip(
    weekNumber: 35,
    title: 'Explore Calling',
    content: '''Help your apprentice think about their life purpose and calling. What has God uniquely designed them to do?

This isn't just about career - it's about understanding how their life can glorify God and serve others.''',
    scripture: 'Ephesians 2:10 - "For we are God\'s handiwork, created in Christ Jesus to do good works, which God prepared in advance for us to do."',
    actionStep: 'Spend time discussing what your apprentice believes God might be calling them to.',
  ),
  WeeklyTip(
    weekNumber: 36,
    title: 'Address Comparison',
    content: '''Comparison steals joy. Help your apprentice focus on their own journey rather than measuring against others.

Social media amplifies comparison. Discuss how to engage with it healthily and where to find true identity.''',
    scripture: 'Galatians 6:4 - "Each one should test their own actions. Then they can take pride in themselves alone, without comparing themselves to someone else."',
    actionStep: 'Ask your apprentice who they tend to compare themselves to and why.',
  ),
  WeeklyTip(
    weekNumber: 37,
    title: 'Practice Gratitude',
    content: '''Gratitude transforms perspective. Encourage your apprentice to regularly count blessings.

Starting meetings by sharing things you're grateful for sets a positive tone and builds the habit of thankfulness.''',
    scripture: '1 Thessalonians 5:18 - "Give thanks in all circumstances; for this is God\'s will for you in Christ Jesus."',
    actionStep: 'Begin your next meeting by each sharing three things you\'re grateful for.',
  ),
  WeeklyTip(
    weekNumber: 38,
    title: 'Discuss Money',
    content: '''Financial stewardship is a spiritual issue. Many young people need guidance on generosity, saving, and contentment.

This can be a sensitive topic, so approach it carefully. But it's too important to ignore.''',
    scripture: 'Matthew 6:21 - "For where your treasure is, there your heart will be also."',
    actionStep: 'If appropriate, ask your apprentice about their approach to finances and generosity.',
  ),
  WeeklyTip(
    weekNumber: 39,
    title: 'Encourage Worship',
    content: '''Worship is more than Sunday morning. Help your apprentice develop a lifestyle of worship.

This includes corporate worship, personal worship through music, and worship through daily living and gratitude.''',
    scripture: 'Romans 12:1 - "Therefore, I urge you, brothers and sisters, in view of God\'s mercy, to offer your bodies as a living sacrifice, holy and pleasing to God—this is your true and proper worship."',
    actionStep: 'Discuss what worship looks like in your apprentice\'s daily life.',
  ),

  // Q4: Weeks 40-52 - Looking Forward
  WeeklyTip(
    weekNumber: 40,
    title: 'Discuss Relationships',
    content: '''Relationships shape us. Help your apprentice evaluate their closest relationships and their influence.

Encourage healthy friendships and discuss dating/marriage from a faith perspective if relevant.''',
    scripture: '1 Corinthians 15:33 - "Do not be misled: Bad company corrupts good character."',
    actionStep: 'Ask your apprentice about their closest friendships and their impact.',
  ),
  WeeklyTip(
    weekNumber: 41,
    title: 'Face Fear Together',
    content: '''Fear holds many people back from God's best. Help your apprentice identify and face their fears.

This might be fear of failure, rejection, the future, or something else. Walking alongside them in facing fear is powerful.''',
    scripture: '2 Timothy 1:7 - "For the Spirit God gave us does not make us timid, but gives us power, love and self-discipline."',
    actionStep: 'Ask your apprentice what fear is currently most limiting to their growth.',
  ),
  WeeklyTip(
    weekNumber: 42,
    title: 'Plan for Growth',
    content: '''Intentional growth doesn't happen by accident. Help your apprentice set specific spiritual growth goals.

What books will they read? What habits will they develop? What areas need focused attention?''',
    scripture: '2 Peter 3:18 - "But grow in the grace and knowledge of our Lord and Savior Jesus Christ."',
    actionStep: 'Help your apprentice set 2-3 specific growth goals for the coming months.',
  ),
  WeeklyTip(
    weekNumber: 43,
    title: 'Discuss Hard Seasons',
    content: '''Life will bring hard seasons. Prepare your apprentice for how to walk with God when times are tough.

Share how you've navigated difficulty. Point them to Psalms of lament and biblical examples of faithful suffering.''',
    scripture: 'Psalm 23:4 - "Even though I walk through the darkest valley, I will fear no evil, for you are with me."',
    actionStep: 'Discuss how your apprentice typically responds to difficult seasons.',
  ),
  WeeklyTip(
    weekNumber: 44,
    title: 'Encourage Evangelism',
    content: '''Help your apprentice share their faith naturally. Many believers feel unequipped or scared to talk about Jesus.

Discuss their personal testimony and how to share it. Look for opportunities to demonstrate evangelism together.''',
    scripture: '1 Peter 3:15 - "Always be prepared to give an answer to everyone who asks you to give the reason for the hope that you have."',
    actionStep: 'Help your apprentice articulate their testimony in a clear, concise way.',
  ),
  WeeklyTip(
    weekNumber: 45,
    title: 'Invest in Their Potential',
    content: '''See your apprentice not just for who they are now, but who they can become. Speak to their potential.

Your belief in them may be the encouragement they need to step into what God has for them.''',
    scripture: 'Ephesians 3:20 - "Now to him who is able to do immeasurably more than all we ask or imagine, according to his power that is at work within us."',
    actionStep: 'Share with your apprentice what potential you see in them.',
  ),
  WeeklyTip(
    weekNumber: 46,
    title: 'Build Independence',
    content: '''The goal isn't to create dependence on you, but to develop someone who can walk with God on their own.

Gradually give them more responsibility and decision-making. Your role should decrease as their maturity increases.''',
    scripture: 'Ephesians 4:13 - "Until we all reach unity in the faith and in the knowledge of the Son of God and become mature, attaining to the whole measure of the fullness of Christ."',
    actionStep: 'Evaluate: Is your apprentice becoming more or less dependent on you? Adjust accordingly.',
  ),
  WeeklyTip(
    weekNumber: 47,
    title: 'Prepare Them to Mentor',
    content: '''The best outcome is when your apprentice goes on to mentor others. Plant seeds for this early.

Discuss the value of mentoring and how they might serve as a mentor in the future.''',
    scripture: '2 Timothy 2:2 - "And the things you have heard me say in the presence of many witnesses entrust to reliable people who will also be qualified to teach others."',
    actionStep: 'Ask your apprentice if they\'ve considered mentoring someone else someday.',
  ),
  WeeklyTip(
    weekNumber: 48,
    title: 'Express Appreciation',
    content: '''Take time to express genuine appreciation for your apprentice. Let them know they matter to you.

Specific, sincere appreciation builds confidence and strengthens your relationship.''',
    scripture: 'Philippians 1:3 - "I thank my God every time I remember you."',
    actionStep: 'Write your apprentice a note expressing specific things you appreciate about them.',
  ),
  WeeklyTip(
    weekNumber: 49,
    title: 'Discuss Legacy',
    content: '''How does your apprentice want to be remembered? Help them think about the legacy they're building.

Daily choices shape long-term impact. Connect present decisions to future outcomes.''',
    scripture: 'Proverbs 13:22 - "A good person leaves an inheritance for their children\'s children."',
    actionStep: 'Ask your apprentice what legacy they hope to leave.',
  ),
  WeeklyTip(
    weekNumber: 50,
    title: 'Review the Journey',
    content: '''Look back at how far your apprentice has come. Recall specific growth, answered prayers, and overcome challenges.

Remembering God's faithfulness builds faith for the future. Don't let growth go unnoticed.''',
    scripture: 'Psalm 77:11 - "I will remember the deeds of the Lord; yes, I will remember your miracles of long ago."',
    actionStep: 'Create a list together of significant growth moments from your mentoring relationship.',
  ),
  WeeklyTip(
    weekNumber: 51,
    title: 'Look Ahead with Hope',
    content: '''Help your apprentice look to the future with hope and expectation. What is God going to do next?

Faith is forward-looking. Encourage them to dream and trust God for what's ahead.''',
    scripture: 'Jeremiah 29:11 - "For I know the plans I have for you, declares the Lord, plans to prosper you and not to harm you, plans to give you hope and a future."',
    actionStep: 'Discuss with your apprentice what they\'re hoping and praying for in the coming year.',
  ),
  WeeklyTip(
    weekNumber: 52,
    title: 'Reflect on the Year',
    content: '''Take time to look back at how far your apprentice has come this year. Celebrate growth, acknowledge challenges, and give thanks to God.

End the year with gratitude and excitement for continued growth. This is just one chapter of their ongoing story with God.''',
    scripture: 'Psalm 103:2 - "Praise the Lord, my soul, and forget not all his benefits."',
    actionStep: 'Have a special year-end conversation to celebrate and reflect together.',
  ),
];
