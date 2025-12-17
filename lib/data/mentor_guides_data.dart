/// Mentor Guides Data
/// Categorized guides for mentor education and development

class MentorGuide {
  final String id;
  final String title;
  final String summary;
  final String category;
  final String content;
  final String? iconName;
  final int readTimeMinutes;

  const MentorGuide({
    required this.id,
    required this.title,
    required this.summary,
    required this.category,
    required this.content,
    this.iconName,
    this.readTimeMinutes = 5,
  });
}

class GuideCategory {
  final String id;
  final String name;
  final String description;
  final String iconName;

  const GuideCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.iconName,
  });
}

/// Available categories for mentor guides
const List<GuideCategory> guideCategories = [
  GuideCategory(
    id: 'getting-started',
    name: 'Getting Started',
    description: 'Foundational guides for new mentors',
    iconName: 'rocket_launch',
  ),
  GuideCategory(
    id: 'communication',
    name: 'Communication',
    description: 'Effective conversation and listening skills',
    iconName: 'chat_bubble',
  ),
  GuideCategory(
    id: 'spiritual-growth',
    name: 'Spiritual Growth',
    description: 'Guiding apprentices in their faith journey',
    iconName: 'self_improvement',
  ),
  GuideCategory(
    id: 'challenges',
    name: 'Common Challenges',
    description: 'Navigating difficult situations',
    iconName: 'psychology',
  ),
  GuideCategory(
    id: 'resources',
    name: 'Tools & Resources',
    description: 'Practical tools for mentoring',
    iconName: 'build',
  ),
];

/// Get guides by category
List<MentorGuide> getGuidesByCategory(String categoryId) {
  return mentorGuides.where((guide) => guide.category == categoryId).toList();
}

/// Get a guide by ID
MentorGuide? getGuideById(String guideId) {
  try {
    return mentorGuides.firstWhere((guide) => guide.id == guideId);
  } catch (e) {
    return null;
  }
}

/// Get category by ID
GuideCategory? getCategoryById(String categoryId) {
  try {
    return guideCategories.firstWhere((cat) => cat.id == categoryId);
  } catch (e) {
    return null;
  }
}

/// All mentor guides
const List<MentorGuide> mentorGuides = [
  // Getting Started Category
  MentorGuide(
    id: 'first-meeting',
    title: 'Your First Meeting',
    summary: 'How to make your first mentoring session successful',
    category: 'getting-started',
    readTimeMinutes: 7,
    iconName: 'handshake',
    content: '''# Your First Meeting with an Apprentice

The first meeting sets the tone for your entire mentoring relationship. Here's how to make it count.

## Before the Meeting

**Pray specifically** for your apprentice. Ask God to prepare both of your hearts for meaningful connection.

**Review any information** you have about them - their assessment results, background, and goals.

**Prepare your space** whether meeting in person or virtually. Minimize distractions and ensure privacy.

## During the Meeting

### Start with Connection (10-15 minutes)
- Share something about yourself beyond the basics
- Ask open-ended questions about their life
- Look for common ground
- Keep it light and conversational

### Set Expectations (15-20 minutes)
- How often will you meet?
- What's the best way to communicate between meetings?
- What does your apprentice hope to gain?
- What are your boundaries and availability?

### Establish Safety (10 minutes)
- Affirm confidentiality (with appropriate limits)
- Let them know it's okay to be honest
- Share that you're learning too
- Prayer together demonstrates spiritual foundation

### Close with Next Steps (5 minutes)
- Confirm your next meeting time
- Leave them with one thing to think about
- End in prayer if comfortable

## Common First-Meeting Mistakes

❌ **Talking too much** - Let them share more than you
❌ **Jumping into heavy topics** - Build trust first
❌ **Over-promising** - Be realistic about your availability
❌ **Being too formal** - Relax and be yourself
❌ **Skipping prayer** - Spiritual grounding matters

## Sample Questions for Your First Meeting

- "What made you decide to be part of this mentoring program?"
- "Tell me about your faith journey so far."
- "What's one thing you're hoping to work on or grow in?"
- "What's something fun or interesting about your life right now?"
- "How can I best support you?"

Remember: This meeting is about building relationship, not fixing problems. Take your time and enjoy getting to know your apprentice.
''',
  ),
  MentorGuide(
    id: 'mentoring-basics',
    title: 'Mentoring 101',
    summary: 'Understanding the fundamentals of effective mentoring',
    category: 'getting-started',
    readTimeMinutes: 10,
    iconName: 'school',
    content: '''# Mentoring 101: The Fundamentals

## What is Mentoring?

Mentoring is a relationship where a more experienced person helps guide the development of a less experienced person. In Christian mentoring, this includes spiritual formation alongside personal growth.

**Mentoring is:**
- A relationship, not a program
- Walking alongside, not standing above
- Asking questions, not just giving answers
- Sharing life, not just information

**Mentoring is NOT:**
- Therapy or counseling
- Preaching or lecturing
- Fixing or rescuing
- A one-time conversation

## The Biblical Foundation

Scripture is full of mentoring relationships:
- Moses and Joshua
- Elijah and Elisha
- Paul and Timothy
- Jesus and the disciples

2 Timothy 2:2 captures the vision: *"The things you have heard me say in the presence of many witnesses entrust to reliable people who will also be qualified to teach others."*

Mentoring is multiplication - what you pour into one person ripples outward.

## Your Role as a Mentor

### What You Offer
- **Presence** - Consistent, reliable showing up
- **Perspective** - Wisdom from experience and Scripture
- **Prayer** - Faithful intercession
- **Patience** - Grace for the journey
- **Pursuit** - Intentional investment in their growth

### What You DON'T Need to Be
- Perfect or having it all together
- An expert on every topic
- Available 24/7
- Able to solve every problem

## The Mentoring Process

### Phase 1: Establish (Months 1-2)
- Build trust and rapport
- Learn their story and context
- Set expectations and goals
- Create safe space for honesty

### Phase 2: Equip (Months 3-6)
- Address specific growth areas
- Teach and model skills
- Provide accountability
- Challenge comfort zones

### Phase 3: Empower (Months 7-12)
- Increase their ownership
- Celebrate growth and progress
- Prepare for independence
- Cast vision for their future impact

## Keys to Effective Mentoring

1. **Be consistent** - Show up reliably
2. **Be authentic** - Share your real self
3. **Be curious** - Ask more than tell
4. **Be patient** - Growth takes time
5. **Be prayerful** - Depend on God, not yourself

## Common Questions

**How long should mentoring last?**
Typically 6-12 months with regular meetings. Some relationships continue longer, some naturally transition sooner.

**What if I don't know how to help with something?**
That's okay! Be honest, and together you can find resources or people who can help.

**What if my apprentice doesn't seem engaged?**
Have a direct conversation. Ask what would make your time together more valuable. It's okay to acknowledge when something isn't working.

---

*Remember: You're not the hero of your apprentice's story - God is. Your job is to point them to Him and walk alongside them as they grow.*
''',
  ),
  MentorGuide(
    id: 'setting-goals',
    title: 'Setting Goals Together',
    summary: 'How to establish meaningful growth objectives',
    category: 'getting-started',
    readTimeMinutes: 6,
    iconName: 'flag',
    content: '''# Setting Goals Together

Effective mentoring has direction. Goals give your time together purpose and provide a way to measure growth.

## Why Goals Matter

Without goals, mentoring becomes aimless conversation. Goals provide:
- **Focus** - Something specific to work toward
- **Motivation** - Tangible progress builds momentum
- **Accountability** - Clear standards to measure against
- **Celebration** - Milestones to acknowledge

## Types of Goals

### Spiritual Goals
- Establish a daily prayer habit
- Read through a book of the Bible
- Memorize Scripture regularly
- Serve in a ministry area

### Personal Goals
- Develop a specific character trait
- Improve a relationship
- Break a harmful habit
- Build a healthy routine

### Skill Goals
- Learn to share their testimony
- Develop leadership abilities
- Improve communication skills
- Practice conflict resolution

## The SMART Framework

Good goals are SMART:

**S - Specific**: Clear and defined
- ❌ "Read the Bible more"
- ✅ "Read one chapter of Proverbs each morning"

**M - Measurable**: You can track progress
- ❌ "Pray more often"
- ✅ "Pray for 10 minutes daily"

**A - Achievable**: Realistic but stretching
- Consider current capacity
- Start smaller than you think

**R - Relevant**: Connected to real growth needs
- Based on their assessment results
- Addresses actual struggles

**T - Time-bound**: Has a deadline
- "By the end of this month"
- "Over the next 12 weeks"

## The Goal-Setting Conversation

### Ask Discovery Questions
- "What area of your life do you most want to grow?"
- "What would be different if you made progress in this area?"
- "What has held you back from growing in this before?"

### Help Them Own It
The goal should be THEIR goal, not yours. Guide the conversation, but let them decide. Goals they own, they'll pursue.

### Make It Concrete
- What will they DO specifically?
- How often?
- When will they start?
- How will you know if they're making progress?

### Write It Down
Goals written down are more likely to be achieved. Have your apprentice record their goals somewhere they'll see them.

## Following Up on Goals

At each meeting:
1. Ask about progress on their goal
2. Celebrate any wins (even small ones)
3. Problem-solve obstacles
4. Adjust if needed - goals can evolve

## Sample Goals

**For a new believer:**
"Read one chapter of John each day this month and journal one thing I learn."

**For someone struggling with anxiety:**
"Practice the breathing prayer technique three times this week when I feel anxious, and share how it went at our next meeting."

**For a future leader:**
"Lead the discussion in my small group twice this semester and get feedback from the leader."

---

*"The plans of the diligent lead to profit as surely as haste leads to poverty." - Proverbs 21:5*
''',
  ),

  // Communication Category
  MentorGuide(
    id: 'active-listening',
    title: 'The Art of Active Listening',
    summary: 'How to truly hear what your apprentice is saying',
    category: 'communication',
    readTimeMinutes: 8,
    iconName: 'hearing',
    content: '''# The Art of Active Listening

Listening is the most important skill a mentor can develop. When people feel truly heard, transformation becomes possible.

## Why Listening Matters

Most people don't need you to solve their problems - they need to be heard. Active listening:
- Builds trust and safety
- Helps you understand the real issue
- Empowers your apprentice to find their own solutions
- Demonstrates genuine care

## The Listening Ladder

### Level 1: Ignoring
Not listening at all. Distracted, thinking about other things.

### Level 2: Pretend Listening
Nodding and saying "uh-huh" but not really engaged.

### Level 3: Selective Listening
Hearing some things while filtering out others based on your interests.

### Level 4: Attentive Listening
Focused on their words and actively following along.

### Level 5: Empathic Listening
Seeking to understand not just words, but feelings, meaning, and context.

**Aim for Level 5.**

## Active Listening Techniques

### Give Full Attention
- Put away your phone
- Make appropriate eye contact
- Turn your body toward them
- Eliminate distractions

### Use Verbal Encouragers
- "Tell me more"
- "I see"
- "Go on"
- "What happened next?"

### Reflect Back
Paraphrase what you heard:
- "It sounds like you're feeling..."
- "So what you're saying is..."
- "Let me make sure I understand..."

### Ask Clarifying Questions
- "Can you give me an example?"
- "What do you mean by...?"
- "How did that make you feel?"

### Summarize
At natural breaks, summarize what you've heard:
- "So far I'm hearing three things..."
- "The main issue seems to be..."

### Validate Emotions
- "That sounds really frustrating"
- "It makes sense you'd feel that way"
- "That took courage to share"

## Common Listening Mistakes

❌ **Interrupting** - Wait for them to finish
❌ **Planning your response** - Focus on understanding first
❌ **Fixing immediately** - Listen fully before offering solutions
❌ **Making it about you** - "That reminds me of when I..."
❌ **Dismissing feelings** - "You shouldn't feel that way"
❌ **Filling silence** - Let them process

## The 80/20 Rule

Aim to listen 80% of the time and speak only 20%. When you do speak, ask questions more than give advice.

## Listening for What's Underneath

Often what people say isn't the whole story. Listen for:
- **Emotions** - What are they feeling beneath the words?
- **Values** - What do they care most about?
- **Fears** - What are they afraid of?
- **Needs** - What do they really need from you right now?

## Practice Exercise

In your next conversation with your apprentice, try this:
1. Listen for 3-5 minutes without saying anything except brief encouragers
2. Then summarize what you heard before responding
3. Ask how accurate your summary was

You'll be amazed how much more you learn when you truly listen.

---

*"Everyone should be quick to listen, slow to speak and slow to become angry." - James 1:19*
''',
  ),
  MentorGuide(
    id: 'asking-questions',
    title: 'Asking Powerful Questions',
    summary: 'Questions that lead to breakthrough and insight',
    category: 'communication',
    readTimeMinutes: 7,
    iconName: 'help_outline',
    content: '''# Asking Powerful Questions

The right question at the right time can change someone's life. Great mentors are great question-askers.

## Why Questions Matter

Questions:
- Invite reflection rather than defensiveness
- Help people discover their own insights
- Show genuine curiosity and care
- Create ownership of solutions
- Model how to think through issues

## Types of Questions

### Open vs. Closed

**Closed questions** get yes/no answers:
- "Did that make you angry?"
- "Are you going to talk to them?"

**Open questions** invite exploration:
- "How did that make you feel?"
- "What are you considering doing?"

**Use open questions most of the time.**

### Surface vs. Deep

**Surface questions** stay factual:
- "What happened?"
- "When did this start?"

**Deep questions** explore meaning:
- "What do you think that means?"
- "Why does this matter to you?"

## Powerful Question Categories

### Clarifying Questions
- "Can you say more about that?"
- "What do you mean by...?"
- "Help me understand..."

### Feeling Questions
- "How did that make you feel?"
- "What emotions come up when you think about this?"
- "Where do you feel that in your body?"

### Belief Questions
- "What do you believe about yourself in this situation?"
- "What story are you telling yourself?"
- "What would God say about this?"

### Values Questions
- "What's most important to you here?"
- "What would you regret not doing?"
- "What does this reveal about what you care about?"

### Future-Focused Questions
- "What do you want to be true six months from now?"
- "If this was resolved, what would be different?"
- "What's one step you could take this week?"

### Scaling Questions
- "On a scale of 1-10, how important is this?"
- "What would move you from a 5 to a 7?"

### Miracle Questions
- "If you woke up tomorrow and this was solved, what would be different?"

## Questions to Avoid

❌ **Leading questions** - "Don't you think you should...?"
❌ **Why questions** (can feel accusatory) - Instead of "Why did you do that?" try "What led to that decision?"
❌ **Multiple questions at once** - Ask one at a time
❌ **Questions that are really advice** - "Have you thought about...?"

## The Power of Silence

After asking a powerful question:
- Wait
- Don't fill the silence
- Let them think
- Count to 10 if needed

The best insights often come after a pause.

## Sample Powerful Questions

**For starting conversations:**
- "What's been on your mind lately?"
- "What's giving you life right now? What's draining you?"

**For exploring issues:**
- "What do you think is really going on here?"
- "What have you tried? What happened?"
- "What are you afraid of in this situation?"

**For moving forward:**
- "What would you do if you weren't afraid?"
- "What's one small step you could take?"
- "What support do you need?"

**For spiritual growth:**
- "Where do you sense God in this?"
- "What might God be teaching you through this?"
- "What would it look like to trust God here?"

## Practice

Pick 3 questions from this guide that feel natural to you. Use them in your next meeting and notice what happens.

---

*"The purposes of a person's heart are deep waters, but one who has insight draws them out." - Proverbs 20:5*
''',
  ),
  MentorGuide(
    id: 'giving-feedback',
    title: 'Giving Constructive Feedback',
    summary: 'How to speak truth in love effectively',
    category: 'communication',
    readTimeMinutes: 6,
    iconName: 'rate_review',
    content: '''# Giving Constructive Feedback

Speaking truth in love is one of the most valuable gifts you can give. But it requires wisdom, timing, and care.

## Why Feedback Matters

Your apprentice has blind spots. Things others see that they don't. As a trusted mentor, you're in a unique position to offer perspective that can accelerate their growth.

## The Feedback Mindset

Before giving feedback, check your heart:
- Is this for THEIR benefit or MY comfort?
- Am I motivated by love?
- Have I earned the right to speak into this?
- Is this the right time?

## The SBI Model

Structure feedback using Situation-Behavior-Impact:

**Situation**: Describe when/where
"In our conversation last week..."

**Behavior**: Describe what you observed (not interpreted)
"You mentioned that you avoided the conversation with your boss..."

**Impact**: Describe the effect
"I noticed that it seemed to increase your anxiety rather than relieve it."

## Ask Permission

Before diving into feedback, ask:
- "Can I share an observation?"
- "Would you be open to some feedback?"
- "Can I tell you what I'm noticing?"

This respects their autonomy and prepares them to receive.

## Balance Affirmation and Challenge

Don't save all positive feedback for softening criticism. Regularly affirm what's going well. Then when correction is needed, it lands in a context of encouragement.

The "feedback sandwich" (positive-negative-positive) can feel manipulative. Instead, be genuinely encouraging throughout your relationship, and be direct when correction is needed.

## Be Specific

❌ Vague: "You need to be more disciplined."
✅ Specific: "I've noticed you've missed your Bible reading goal three weeks in a row. What's getting in the way?"

❌ Vague: "You were kind of harsh with them."
✅ Specific: "When you said 'that's stupid,' I saw their face fall. How do you think they received that?"

## Focus on Behavior, Not Character

❌ "You're so irresponsible."
✅ "Missing that commitment affected the team. What happened?"

❌ "You're being selfish."
✅ "I noticed you made the decision without asking how it affected others."

## Invite Response

After giving feedback:
- "What do you think about that?"
- "Does that ring true?"
- "What's your perspective?"

They may have context you don't. Be open to adjusting your view.

## Timing Matters

Good feedback at the wrong time is bad feedback. Consider:
- Are they in a place to receive this?
- Is there enough time to process?
- Will privacy allow honest response?
- Are you calm and clear-headed?

## Difficult Feedback Examples

**Noticing patterns:**
"I've noticed that when things get hard, you tend to withdraw. Can we talk about what's going on there?"

**Addressing blind spots:**
"Can I share something I've observed? You might not be aware of this, but when you talk about your parents, there's a lot of anger underneath. Have you noticed that?"

**Calling out potential:**
"I don't think you're giving yourself enough credit. From what I can see, you're capable of more than you're attempting. What would it look like to step up?"

## When Feedback Isn't Received Well

- Don't force it
- Give them time to process
- Revisit later if needed
- Stay relational
- Pray for receptivity

---

*"Wounds from a friend can be trusted, but an enemy multiplies kisses." - Proverbs 27:6*
''',
  ),

  // Spiritual Growth Category
  MentorGuide(
    id: 'guiding-prayer',
    title: 'Guiding Prayer Life',
    summary: 'Helping your apprentice develop a vibrant prayer life',
    category: 'spiritual-growth',
    readTimeMinutes: 8,
    iconName: 'volunteer_activism',
    content: '''# Guiding Prayer Life

Prayer is the heartbeat of spiritual growth. As a mentor, you have the opportunity to help your apprentice develop a rich, authentic prayer life.

## Assess Where They Are

Start by understanding their current prayer life:
- "Tell me about your prayer life right now."
- "When do you find it easiest to pray? Hardest?"
- "What do you usually pray about?"
- "What frustrations do you have with prayer?"

## Common Prayer Struggles

### "I don't know what to say"
- Introduce structure (ACTS: Adoration, Confession, Thanksgiving, Supplication)
- Suggest praying Scripture
- Model conversational prayer

### "I get distracted"
- Try different times/places
- Use a journal
- Start with shorter times
- Walk and pray

### "I don't feel anything"
- Feelings aren't the goal
- Faith is acting regardless of feeling
- Dry seasons are normal

### "I'm not sure God hears me"
- Explore this doubt gently
- Share Scripture about God's attentiveness
- Share your own experiences of answered prayer

## Teaching Different Types of Prayer

### Gratitude Prayer
Start by listing blessings. Gratitude opens the heart to God.

### Confession Prayer
Honest acknowledgment of sin and receiving forgiveness. Not wallowing in guilt, but honest transparency.

### Intercessory Prayer
Praying for others. Keep a list and follow up.

### Listening Prayer
Sitting quietly and asking God to speak. Journaling what comes.

### Breath Prayer
A short phrase repeated with breathing. "Lord Jesus / have mercy on me."

### Praying Scripture
Reading a passage and turning it into prayer. Psalm 23 works beautifully.

## Practical Tips to Share

1. **Set a time** - Prayer that's scheduled happens more than prayer that's "whenever"

2. **Create a space** - A dedicated spot removes decision fatigue

3. **Start small** - 5 consistent minutes beats sporadic 30-minute sessions

4. **Use a list** - Writing requests keeps you focused and lets you see answers

5. **Pray out loud** - When possible, speaking helps focus

6. **Expect answers** - Look for how God responds, even if it's not what you expected

## Praying Together

Model prayer by praying with your apprentice:
- Open and close your sessions in prayer
- Pray for specific things they share
- Occasionally ask them to lead prayer
- Pray for them between meetings

## Resources to Recommend

**Books:**
- "Prayer" by Timothy Keller
- "A Praying Life" by Paul Miller
- "The Circle Maker" by Mark Batterson

**Apps:**
- Pray.com
- Echo Prayer
- PrayerMate

**Practices:**
- Daily Examen (Ignatian prayer)
- Lectio Divina
- Prayer journaling

## Sample Discussion Questions

- "What's one thing blocking your prayer life right now?"
- "If you could ask God anything, what would it be?"
- "When have you experienced an answered prayer?"
- "What would your prayer life look like if you weren't busy?"

---

*"Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God." - Philippians 4:6*
''',
  ),
  MentorGuide(
    id: 'bible-study',
    title: 'Encouraging Bible Study',
    summary: 'Helping your apprentice engage with Scripture',
    category: 'spiritual-growth',
    readTimeMinutes: 7,
    iconName: 'menu_book',
    content: '''# Encouraging Bible Study

Scripture is the primary way God speaks to us. Helping your apprentice develop a habit of engaging with the Bible is one of the most important things you can do.

## Assess Their Starting Point

- Do they own a Bible? What version?
- What's their history with Bible reading?
- What intimidates them about Scripture?
- What parts of the Bible have they explored?

## Addressing Common Barriers

### "I don't understand it"
- Recommend readable translations (NIV, NLT, ESV)
- Suggest starting with narrative books (Mark, Genesis)
- Provide a study Bible with notes
- Use Bible apps with commentary

### "I don't have time"
- Start with 5 minutes
- Pair it with an existing habit (morning coffee)
- Try audio Bibles during commute
- Quality over quantity

### "It feels boring"
- Vary the approach (reading, studying, listening)
- Connect it to current struggles
- Read with a question in mind
- Discuss what they're reading with you

### "I don't know where to start"
- Recommend specific starting points
- Provide a reading plan
- Study together

## Where to Start

**For beginners:**
- Gospel of Mark (shortest Gospel, action-packed)
- Psalm 23, 91, 139 (accessible poetry)
- Proverbs (wisdom for daily life)
- James (practical faith)

**For growing believers:**
- Romans (theology of salvation)
- Ephesians (identity in Christ)
- Genesis (foundational narratives)
- John (deep theology)

## Teaching Study Methods

### The SOAP Method
- **S**cripture - Write out a verse
- **O**bservation - What do you notice?
- **A**pplication - How does this apply to you?
- **P**rayer - Turn it into prayer

### Three Questions
1. What does this say about God?
2. What does this say about people?
3. How should I respond?

### Context Reading
- Who wrote this? To whom?
- What was happening at the time?
- How does this fit in the larger story?

### Meditation
- Read slowly
- Read multiple times
- Ask the Holy Spirit to illuminate
- Sit with one phrase

## Making It Practical

Encourage your apprentice to:
1. **Pick a time and place** - Consistency builds habit
2. **Have tools ready** - Bible, journal, pen
3. **Start small** - One chapter is better than zero
4. **Read actively** - Underline, write notes, ask questions
5. **Apply something** - Don't just read, do

## Studying Together

Consider:
- Reading the same book and discussing weekly
- Going through a study guide together
- Memorizing a passage together
- Asking what they're learning in their reading

## Resources to Recommend

**Apps:**
- YouVersion (Bible app with reading plans)
- Dwell (audio Bible)
- Blue Letter Bible (study tools)

**Tools:**
- Study Bible (ESV Study Bible, NIV Study Bible)
- Bible dictionary
- Commentary for specific books

**Plans:**
- Bible Project reading plans
- Chronological reading plans
- Book-at-a-time approach

## Discussion Questions

- "What have you been reading in Scripture lately?"
- "What's confusing you about the Bible right now?"
- "How has God spoken to you through Scripture recently?"
- "What's one thing you've learned that's changed how you live?"

---

*"Your word is a lamp for my feet, a light on my path." - Psalm 119:105*
''',
  ),
  MentorGuide(
    id: 'spiritual-gifts',
    title: 'Discovering Spiritual Gifts',
    summary: 'Helping your apprentice identify and use their gifts',
    category: 'spiritual-growth',
    readTimeMinutes: 8,
    iconName: 'card_giftcard',
    content: '''# Discovering Spiritual Gifts

Every believer has been given spiritual gifts by the Holy Spirit. Helping your apprentice discover and develop their gifts is deeply affirming and empowering.

## What Are Spiritual Gifts?

Spiritual gifts are abilities given by the Holy Spirit to believers for building up the body of Christ and serving others. They are:
- Given by God (you don't earn them)
- For serving others (not self-glorification)
- Diverse (everyone has different gifts)
- To be developed (gifts grow with use)

## Biblical Gift Lists

Scripture mentions spiritual gifts in several places:

**Romans 12:6-8**
Prophecy, serving, teaching, encouraging, giving, leading, mercy

**1 Corinthians 12:4-11**
Wisdom, knowledge, faith, healing, miracles, prophecy, discernment, tongues, interpretation

**Ephesians 4:11**
Apostles, prophets, evangelists, pastors, teachers

**1 Peter 4:10-11**
Speaking gifts, serving gifts

## Discovering Gifts

### Through Assessment
Use the T[root]H spiritual gifts assessment or similar tools. These provide starting points for reflection.

### Through Experience
- What comes naturally?
- What do others affirm in you?
- What brings you energy when serving?
- Where do you see fruit?

### Through Exploration
- Try different areas of service
- Step out of comfort zones
- Pay attention to what fits

### Through Confirmation
- Others recognize your gifts
- You see impact
- It aligns with Scripture

## Common Spiritual Gifts Explained

**Teaching** - Ability to clearly explain truth in ways others understand

**Encouragement** - Natural ability to uplift and motivate others

**Serving** - Joy in meeting practical needs

**Giving** - Generous sharing of resources

**Leadership** - Ability to cast vision and guide others

**Mercy** - Deep compassion and comfort for those suffering

**Administration** - Organizing and coordinating effectively

**Hospitality** - Creating welcoming environments

**Faith** - Unusual confidence in God's provision and power

**Wisdom** - Applying spiritual insight to situations

## Developing Gifts

Gifts are like muscles - they grow with use.

1. **Identify** - Know what gifts you have
2. **Study** - Learn about your gifts
3. **Practice** - Use them regularly
4. **Reflect** - Evaluate and adjust
5. **Mentor** - Learn from others with the same gift

## Discussing Gifts with Your Apprentice

**Discovery questions:**
- "What do people often thank you for?"
- "What energizes you when you do it?"
- "Where do you naturally see needs others miss?"
- "What do you do that seems to impact others?"

**Development questions:**
- "How are you currently using this gift?"
- "What would it look like to grow in this area?"
- "Who could mentor you in using this gift?"
- "Where could you serve that uses your gifts?"

## Warning Signs

Help your apprentice avoid:
- **Gift envy** - Wishing for others' gifts
- **Gift neglect** - Ignoring what God has given
- **Gift pride** - Using gifts for self-glory
- **Gift excuse** - Using "not my gift" to avoid serving

## Connecting Gifts to Service

Help them find places to serve that match their gifting:
- Teaching gift → small group leader, children's ministry
- Serving gift → hospitality team, practical help ministries
- Encouragement → greeting, follow-up, care team
- Leadership → ministry coordination, team leading

---

*"Each of you should use whatever gift you have received to serve others, as faithful stewards of God's grace in its various forms." - 1 Peter 4:10*
''',
  ),

  // Challenges Category
  MentorGuide(
    id: 'when-stuck',
    title: 'When Your Apprentice Is Stuck',
    summary: 'Breaking through when growth stalls',
    category: 'challenges',
    readTimeMinutes: 7,
    iconName: 'pause_circle',
    content: '''# When Your Apprentice Is Stuck

Every apprentice hits plateaus. Knowing how to respond when growth stalls is a critical mentoring skill.

## Recognizing "Stuck"

Signs your apprentice might be stuck:
- Same issues keep coming up
- Goals not being met repeatedly
- Energy and enthusiasm declining
- Avoiding or canceling meetings
- Surface-level conversations
- Resistance to feedback or challenge

## Possible Causes

### External Factors
- Life circumstances (stress, transitions)
- Unhealthy relationships
- Time/schedule challenges
- Health issues

### Internal Factors
- Fear of change
- Hidden sin or shame
- Unresolved wounds
- Unclear motivation
- Discouragement

### Mentoring Factors
- Wrong goals
- Moving too fast
- Trust issues
- Mismatch in expectations

## Addressing the Plateau

### 1. Name It
"I've noticed we seem to be hitting the same wall. Can we talk about that?"

Being direct opens the door. Don't pretend everything is fine.

### 2. Explore Without Judgment
"What do you think is getting in the way?"
"What are you afraid might happen if you moved forward?"
"Is there something you haven't shared that might be relevant?"

### 3. Check Your Approach
- Are the goals right?
- Have you been doing all the talking?
- Is there enough trust for honesty?
- Have you been too soft or too hard?

### 4. Try Something Different
- Meet in a different location
- Change your focus for a few meetings
- Bring in a resource (book, video, exercise)
- Take a walk instead of sitting
- Invite deeper vulnerability by sharing yours first

### 5. Consider Taking a Break
Sometimes a short pause helps. "Let's take two weeks and then come back together. During that time, I'd love for you to think about what you really want from our remaining time together."

## Conversations for Breakthrough

**When you suspect fear:**
"What's the worst that could happen if you tried this?"
"What would you do if you knew you couldn't fail?"

**When motivation is unclear:**
"Why does this matter to you? Really?"
"If nothing changes, what will your life look like in a year?"

**When there's hidden shame:**
"Is there anything you've been hesitant to share? I'm here and I won't judge."

**When they're overwhelmed:**
"Let's forget about everything else. What's the one smallest step you could take?"

## What NOT to Do

❌ **Push harder** - Pressure usually creates resistance
❌ **Ignore it** - Hoping it resolves rarely works
❌ **Shame them** - "You should be further along by now"
❌ **Rescue them** - Doing the work for them
❌ **Give up** - Plateaus are normal, not failures

## When to Seek Help

Sometimes being stuck indicates something beyond mentoring:
- Deep depression or anxiety
- Trauma responses
- Addiction
- Serious relational dysfunction

Know your limits and have referral options ready.

## Remember

Plateaus are part of growth, not evidence of failure. Your consistent, patient presence through stuck seasons may be exactly what your apprentice needs.

---

*"Let us not become weary in doing good, for at the proper time we will reap a harvest if we do not give up." - Galatians 6:9*
''',
  ),
  MentorGuide(
    id: 'difficult-conversations',
    title: 'Navigating Difficult Conversations',
    summary: 'How to address sensitive topics with grace',
    category: 'challenges',
    readTimeMinutes: 8,
    iconName: 'forum',
    content: '''# Navigating Difficult Conversations

Some of the most important moments in mentoring are the hardest. Knowing how to navigate difficult conversations is essential.

## Common Difficult Conversations

- Addressing sin or harmful behavior
- Discussing mental health concerns
- Talking about broken relationships
- Exploring doubt and faith struggles
- Confronting lack of follow-through
- Discussing sensitive topics (sexuality, addiction, trauma)

## Before the Conversation

### Prepare Yourself
- Pray for wisdom and the right words
- Check your motives (love, not frustration)
- Plan what you want to say
- Anticipate reactions
- Choose the right time and place

### Prepare Your Heart
- Release any anger or judgment
- Remind yourself of your own need for grace
- Focus on their best interest
- Trust God with the outcome

## During the Conversation

### Start with Care
- "I want to talk about something important because I care about you."
- "Can we discuss something that's been on my mind?"
- "I've been praying about how to bring this up..."

### Be Direct but Kind
Don't bury the issue in softness, but don't be harsh either.

❌ Too soft: "I mean, it's probably not a big deal, but maybe sometimes you might want to consider..."

❌ Too hard: "You have a serious problem and you need to fix it."

✅ Just right: "I've observed [specific behavior] and I'm concerned about [impact]. Can we talk about it?"

### Use "I" Statements
- "I've noticed..." (not "You always...")
- "I feel concerned when..." (not "You make me feel...")
- "I want to understand..." (not "You need to explain...")

### Listen Fully
After sharing your concern, stop talking. Let them respond. Really listen.
- They may have context you don't know
- Their perspective matters
- Listening builds trust even in hard moments

### Stay Curious
- "Help me understand..."
- "What's going on underneath this?"
- "What was happening when this started?"

### Affirm the Relationship
- "Nothing changes how much I care about you."
- "I'm bringing this up because you matter to me."
- "We're going to work through this together."

## Handling Reactions

### If They Get Defensive
- Don't escalate
- Validate their feelings: "I understand this is hard to hear"
- Stay calm and patient
- You may need to revisit later

### If They Shut Down
- Give space: "I can see this hit you hard. We don't have to solve it today."
- Follow up later
- Keep showing up

### If They Get Angry
- Don't match their intensity
- Let them express it without interrupting
- Set boundaries if needed: "I want to keep talking, but I need us to be respectful"

### If They Cry
- Silence is okay
- Don't rush to fix it
- Offer comfort: "I'm here. Take your time."

## After the Conversation

- Pray for them
- Give them space to process
- Follow up appropriately
- Keep the relationship warm
- Celebrate any progress

## Sample Scripts

**Addressing repeated sin:**
"I've noticed you've mentioned struggling with [X] a few times now. I care about you too much to just keep moving past it. Can we really dig into what's going on?"

**Expressing concern about mental health:**
"The things you've been sharing make me wonder if this is more than normal stress. Have you thought about talking to a counselor? I think it could really help."

**Confronting broken commitment:**
"You've missed our last three meetings. I want to be understanding, but I also want to be honest that I'm concerned. What's going on?"

---

*"Speaking the truth in love, we will grow to become in every respect the mature body of him who is the head, that is, Christ." - Ephesians 4:15*
''',
  ),
  MentorGuide(
    id: 'crisis-situations',
    title: 'Responding to Crisis',
    summary: 'What to do when your apprentice faces serious struggles',
    category: 'challenges',
    readTimeMinutes: 6,
    iconName: 'emergency',
    content: '''# Responding to Crisis

Sometimes your apprentice will face situations that go beyond normal mentoring. Knowing how to respond to crisis is critical.

## Recognizing Crisis

Crisis situations may include:
- Suicidal thoughts or self-harm
- Abuse (experiencing or perpetrating)
- Severe mental health episodes
- Major trauma
- Addiction spiraling
- Family emergencies
- Legal issues

## Immediate Response Principles

### 1. Stay Calm
Your calm presence helps stabilize the situation. Don't panic, even if you're alarmed internally.

### 2. Listen First
Before jumping to action, understand what's happening. Ask open questions:
- "Can you tell me what's going on?"
- "When did this start?"
- "Are you safe right now?"

### 3. Show Compassion
- "I'm so glad you told me."
- "You're not alone in this."
- "We're going to figure this out together."

### 4. Assess Safety
If there's immediate danger (to self or others):
- Ask directly: "Are you thinking about hurting yourself?"
- Don't leave them alone
- Involve emergency services if needed (911)
- Contact their emergency contacts

### 5. Don't Promise Secrecy
If safety is at risk, you may need to involve others. Be honest: "I care about you too much to keep this to myself if your safety is at stake."

## Know Your Limits

**You are NOT:**
- A therapist
- A crisis counselor
- An emergency responder
- Responsible for fixing everything

**You ARE:**
- A caring presence
- A connector to resources
- A faithful friend
- A prayer partner

## When to Involve Others

Involve professional help when:
- There's mention of suicide or self-harm
- Abuse is disclosed (may be mandatory reporting)
- Symptoms of severe mental illness
- Substance abuse beyond your ability to help
- Anything that makes you feel "this is beyond me"

## Resources to Know

Have these ready BEFORE a crisis:
- **National Suicide Prevention Lifeline**: 988
- **Crisis Text Line**: Text HOME to 741741
- **Local emergency services**: 911
- **Church pastoral care contacts**
- **Local Christian counselors**
- **Abuse hotline**: 1-800-422-4453

## After the Immediate Crisis

### Follow Up
- Check in more frequently
- Don't pretend it didn't happen
- Ask how they're doing

### Support Professional Help
- Encourage continued counseling
- Help them find resources
- Offer to go with them to first appointment

### Process Your Own Response
- Talk to a pastor or supervisor
- Don't carry this alone
- Practice self-care

### Maintain the Relationship
- Crisis doesn't end mentoring (usually)
- Adjust expectations as needed
- Keep showing up

## What NOT to Do

❌ Promise you can fix it
❌ Share their crisis with others unnecessarily
❌ Disappear because it got hard
❌ Try to be their therapist
❌ Make it about your feelings
❌ Guilt or shame them

## Sample Response

If an apprentice reveals they've been having suicidal thoughts:

"Thank you for trusting me with something so serious. I'm really glad you told me. Are you safe right now? I want to make sure we get you the support you need. I'm going to walk through this with you, and we're going to make sure you talk to someone trained to help. You're not alone."

---

*"The Lord is close to the brokenhearted and saves those who are crushed in spirit." - Psalm 34:18*
''',
  ),

  // Tools & Resources Category
  MentorGuide(
    id: 'meeting-structure',
    title: 'Structuring Your Meetings',
    summary: 'A framework for effective mentoring sessions',
    category: 'resources',
    readTimeMinutes: 6,
    iconName: 'event_note',
    content: '''# Structuring Your Meetings

A good structure helps your meetings be both relational and productive. Here's a flexible framework to adapt.

## The 60-Minute Meeting

### Check-In (10-15 minutes)
- How are you doing? Really?
- What's been happening since we last met?
- What's on your mind today?

This is relational connection time. Don't rush it, but don't let it consume the whole meeting either.

### Review (5-10 minutes)
- How did last week's action steps go?
- Any updates on goals we've been tracking?
- What did you learn or experience?

Accountability happens here. Celebrate wins, address misses without shame.

### Main Discussion (25-30 minutes)
This is where the bulk of your conversation happens:
- Address their current questions or struggles
- Discuss a planned topic
- Work through assessment feedback
- Study Scripture together
- Practice a skill

Stay flexible - sometimes what they need to discuss isn't what you planned.

### Application (10 minutes)
- What's one takeaway from today?
- What's one specific action step?
- How can I pray for you?

Don't skip this. Movement happens when insights become actions.

### Closing Prayer (5 minutes)
Pray together. Pray for their specific needs. Let them hear you bring their life before God.

## Adapting the Structure

### Shorter Meetings (30 minutes)
- Quick check-in (5 min)
- Focused discussion (20 min)
- Action step + prayer (5 min)

### Longer Meetings (90 minutes)
- Extended connection time
- Deeper discussion
- Maybe share a meal
- More room for tangents

### Crisis Meetings
Throw the structure out. Be fully present. Listen. Pray.

### Celebration Meetings
Mark milestones (end of study, completed goal). Make it special.

## Meeting Rhythm Suggestions

**Weekly meetings** work well for:
- Early stages of relationship
- Intensive growth periods
- Accountability focus

**Bi-weekly meetings** work well for:
- Established relationships
- Maintaining momentum
- Busy seasons

**Monthly meetings** work well for:
- Long-term mentoring
- Maintenance mode
- Transitioning out

## Between Meetings

Stay connected:
- Send encouraging texts
- Pray for them daily
- Follow up on specific things they shared
- Share relevant resources

But also maintain boundaries - you're not available 24/7.

## Practical Tips

1. **Start on time** - Respect their schedule
2. **End on time** - Unless they clearly need more
3. **Put phones away** - Give full attention
4. **Take brief notes** - Remember what matters to follow up
5. **Prepare loosely** - Have a plan but hold it loosely
6. **Protect the time** - Don't cancel casually

## Sample Meeting Agenda

**Meeting with [Name] - [Date]**

☐ Check-in: How are they really doing?
☐ Review: Progress on [goal/action step]
☐ Discuss: [Topic or question for today]
☐ Apply: What's one thing they'll do this week?
☐ Pray: Specific requests

Notes: _______________

---

*"Where there is no guidance, a people falls, but in an abundance of counselors there is safety." - Proverbs 11:14*
''',
  ),
  MentorGuide(
    id: 'prayer-practices',
    title: 'Prayer Practices for Mentors',
    summary: 'How to pray for and with your apprentice',
    category: 'resources',
    readTimeMinutes: 5,
    iconName: 'front_hand',
    content: '''# Prayer Practices for Mentors

Prayer is the foundation of effective mentoring. Here are practical ways to pray for and with your apprentice.

## Praying FOR Your Apprentice

### Daily Prayer
Set aside time each day to pray for your apprentice. Even 2-3 minutes makes a difference.

### Specific Prayer
Pray for specific things they've shared:
- The job interview on Thursday
- Their relationship with their father
- Breaking the anxiety pattern
- Growing in patience

Keep a list so you don't forget.

### Scripture Prayer
Pray Scripture over them:

*"I pray that the eyes of [name]'s heart may be enlightened so that they may know the hope of your calling..." (Eph 1:18)*

*"I pray that [name] may be filled with the knowledge of your will through all spiritual wisdom and understanding." (Col 1:9)*

### Protection Prayer
Pray for God's protection over their life, mind, relationships, and spiritual growth.

### Future Prayer
Pray for who they're becoming. Pray for their future family, ministry, and impact.

## Praying WITH Your Apprentice

### Opening Prayer
Start meetings with brief prayer. Model that your time together is rooted in dependence on God.

### Closing Prayer
End by praying for what was discussed. Be specific. Let them hear their needs lifted to God.

### Invite Them to Pray
Regularly ask them to pray too. This builds their confidence and shows their prayers matter.

### Prayer Walks
Occasionally walk and pray together. Movement can free up conversation and prayer.

### Silence Together
Try sitting in silent prayer for a few minutes. This practices listening to God together.

## When Your Apprentice Struggles to Pray

### Normalize It
"Prayer is hard sometimes. That's normal."

### Start Small
"Can you just tell God one thing you're grateful for?"

### Model Simple Prayer
Keep your prayers conversational, not flowery. Show that prayer doesn't require special words.

### Write It First
Sometimes writing a prayer and then reading it aloud helps.

### Prompt Them
"What would you want to say to God about this situation?"

## Prayer Ideas for Meetings

1. **Gratitude round** - Each share 3 things you're thankful for, then thank God together

2. **Confession moment** - Silent confession, then receive grace together

3. **Prayer for others** - Pray for people in their life

4. **Listening prayer** - Sit quietly and ask, "God, what do you want us to know?"

5. **Scripture prayer** - Read a psalm and use it as the basis for prayer

## Keeping Track

Keep a simple prayer log:
- What you prayed for
- Dates
- Answers

Review it periodically with your apprentice. Seeing answered prayer builds faith.

---

*"The prayer of a righteous person is powerful and effective." - James 5:16*
''',
  ),
  MentorGuide(
    id: 'recommended-books',
    title: 'Recommended Books',
    summary: 'Books to read yourself or recommend to your apprentice',
    category: 'resources',
    readTimeMinutes: 5,
    iconName: 'local_library',
    content: '''# Recommended Books for Mentoring

Build your library and have resources ready to recommend.

## For Mentors

### On Mentoring
- **"The Mentor Leader"** by Tony Dungy - Leadership through mentoring
- **"Mentoring 101"** by John Maxwell - Practical mentoring basics
- **"As Iron Sharpens Iron"** by Howard Hendricks - Biblical mentoring principles

### On Spiritual Formation
- **"Celebration of Discipline"** by Richard Foster - Classic on spiritual practices
- **"The Spirit of the Disciplines"** by Dallas Willard - Theology of spiritual formation
- **"Emotionally Healthy Spirituality"** by Peter Scazzero - Integrating emotional and spiritual health

### On Listening & Questions
- **"The Coaching Habit"** by Michael Bungay Stanier - Great questions framework
- **"Just Listen"** by Mark Goulston - Deep listening skills

## For Apprentices

### For New Believers
- **"Basic Christianity"** by John Stott - Foundation of faith
- **"More Than a Carpenter"** by Josh McDowell - Answering tough questions
- **"The Pursuit of God"** by A.W. Tozer - Cultivating hunger for God

### For Growing Faith
- **"Mere Christianity"** by C.S. Lewis - Timeless apologetics and theology
- **"The Reason for God"** by Tim Keller - Modern apologetics
- **"Knowing God"** by J.I. Packer - Deeper understanding of God's nature

### For Spiritual Practices
- **"Prayer"** by Tim Keller - Practical and theological
- **"A Praying Life"** by Paul Miller - Making prayer real
- **"Spiritual Disciplines Handbook"** by Adele Calhoun - Comprehensive guide

### For Identity & Purpose
- **"You Are What You Love"** by James K.A. Smith - Habit and desire
- **"The Me I Want to Be"** by John Ortberg - Becoming your best self
- **"Let Your Life Speak"** by Parker Palmer - Vocation and calling

### For Relationships
- **"Boundaries"** by Cloud & Townsend - Healthy relationship limits
- **"The Five Love Languages"** by Gary Chapman - Understanding love
- **"Safe People"** by Cloud & Townsend - Choosing healthy relationships

### For Character
- **"The Road to Character"** by David Brooks - Building inner virtues
- **"Renovation of the Heart"** by Dallas Willard - Soul transformation

### For Hard Seasons
- **"A Grief Observed"** by C.S. Lewis - Processing loss
- **"Walking with God through Pain and Suffering"** by Tim Keller
- **"When God Doesn't Fix It"** by Laura Story - Living with unanswered prayer

## How to Use Books in Mentoring

1. **Read together** - Same book, discuss chapters each meeting
2. **Assign and discuss** - They read, you process together
3. **Strategic recommendation** - Match book to current struggle
4. **Excerpts** - Share a chapter or quote that speaks to their situation

## Beyond Books

**Podcasts:**
- The Bible Project
- Timothy Keller sermons
- Ask NT Wright Anything

**Videos:**
- RightNow Media (church subscription)
- The Bible Project YouTube
- Alpha series

**Devotionals:**
- Jesus Calling by Sarah Young
- My Utmost for His Highest by Oswald Chambers
- Morning and Evening by Charles Spurgeon

---

*"Of making many books there is no end, and much study wearies the body." - Ecclesiastes 12:12*

Choose wisely - a few great books beat many mediocre ones.
''',
  ),
];
