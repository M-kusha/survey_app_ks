#!/usr/bin/env node
'use strict';

const path = require('path');
const { createRequire } = require('module');

function admin(module) {
  try {
    return require(module);
  } catch (error) {
    if (error.code !== 'MODULE_NOT_FOUND') throw error;
    const fromFunctions = createRequire(
      path.join(__dirname, '..', 'functions', 'package.json'),
    );
    return fromFunctions(module);
  }
}

const { initializeApp, applicationDefault, cert } = admin('firebase-admin/app');
const { getFirestore, Timestamp } = admin('firebase-admin/firestore');

const PREFIX = 'seed-demo-';
const PROJECT_ID = 'echomeet-app';
const DRY_RUN = process.argv.includes('--dry-run');

function credential() {
  const key = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  return key ? cert(require(key)) : applicationDefault();
}

let cached;
function firestore() {
  if (!cached) {
    initializeApp({ credential: credential(), projectId: PROJECT_ID });
    cached = getFirestore();
  }
  return cached;
}

const DAY = 24 * 60 * 60 * 1000;
const HOUR = 60 * 60 * 1000;

function at(offsetDays, hour = 10) {
  const when = new Date(Date.now() + offsetDays * DAY);
  when.setHours(hour, 0, 0, 0);
  return when.getTime();
}

const AGREE = ['Strongly agree', 'Agree', 'Neutral', 'Disagree', 'Strongly disagree'];
const FREQ = ['Daily', 'Weekly', 'Monthly', 'Rarely', 'Never'];
const YESNO = ['Yes', 'No'];
const RATE = ['Excellent', 'Good', 'Adequate', 'Poor'];

const S = (question, options) => ['Single', question, options];
const M = (question, options) => ['Multiple', question, options];
const T = (question) => ['Text', question];

const SURVEYS = [
  ['Workplace environment', 'Light, noise, temperature and desks.', -6, [
    S('How does the office temperature feel most days?', ['Too cold', 'About right', 'Too warm', 'It swings']),
    S('The lighting at my desk is comfortable.', AGREE),
    S('How often is noise a problem for you?', FREQ),
    S('How would you rate the desk and chair you use?', RATE),
    M('Which spaces do you actually use?', ['Quiet room', 'Meeting rooms', 'Kitchen', 'Balcony', 'Phone booths']),
    S('Is there somewhere to take a private call?', YESNO),
    S('How would you rate the cleanliness of shared areas?', RATE),
    S('I can find a free meeting room when I need one.', AGREE),
    S('How often do you work from the office?', FREQ),
    S('Would you use a bookable desk system?', ['Yes', 'No', 'Only on busy days']),
    T('What one change would improve the workspace most?'),
  ]],
  ['Hybrid working', 'How we split the week from next quarter.', 1, [
    S('How many days would you prefer in the office?', ['None', 'One', 'Two', 'Three', 'Four or five']),
    M('Which days suit you best?', ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']),
    S('Do you have a usable desk at home?', ['Yes', 'No', 'Partly']),
    S('My internet at home is reliable enough for video calls.', AGREE),
    S('How long is your commute, one way?', ['Under 15 minutes', '15 to 30', '30 to 60', 'Over an hour']),
    S('I get more focused work done at home than in the office.', AGREE),
    S('How often do you feel out of the loop when working remotely?', FREQ),
    M('What would make office days worth the trip?', ['Team all in', 'Better desks', 'Free lunch', 'Workshops', 'Nothing would']),
    S('Should core hours be fixed for everyone?', ['Yes', 'No', 'Only for meetings']),
    S('How would you rate our remote meeting etiquette?', RATE),
    T('What would make hybrid work better for you?'),
  ]],
  ['Team lunch and catering', 'Picking the caterer for the offsite.', 2, [
    S('Which cuisine would you pick first?', ['Italian', 'Mexican', 'Balkan', 'Japanese', 'Indian']),
    M('Any dietary requirements?', ['Vegetarian', 'Vegan', 'Gluten free', 'Halal', 'None']),
    S('How important is a hot option?', ['Essential', 'Nice to have', 'Not important']),
    S('Preferred lunch time?', ['12:00', '12:30', '13:00', 'Flexible']),
    S('Should we cover drinks as well?', YESNO),
    M('Which venues would you consider?', ['Office kitchen', 'Restaurant nearby', 'Outdoor terrace', 'Rented space']),
    S('How often should we do a team lunch?', ['Weekly', 'Monthly', 'Quarterly', 'Twice a year']),
    S('Would you attend if it ran past 17:00?', ['Yes', 'No', 'Depends on the day']),
    S('A shared table beats individual orders.', AGREE),
    S('A budget of 25 per person feels right.', AGREE),
    T('Anything the caterer should know?'),
  ]],
  ['Tooling review', 'What we keep paying for next year.', 9, [
    S('How often do you use the project tracker?', FREQ),
    S('How often do you use the design tool?', FREQ),
    S('How often do you use the wiki?', FREQ),
    S('How would you rate our chat tool?', RATE),
    M('Which tools would you drop tomorrow?', ['Tracker', 'Design tool', 'Chat', 'Wiki', 'None of them']),
    S('Our tools slow me down more than they help.', AGREE),
    S('How long does your environment take to set up from scratch?', ['Under an hour', 'Half a day', 'A full day', 'Longer']),
    S('Do you have the licences you need?', ['Yes', 'No', 'I had to ask twice']),
    M('Where do you lose the most time?', ['Waiting on builds', 'Finding documentation', 'Switching tools', 'Manual steps', 'Meetings']),
    S('Is the current setup fast enough?', ['Yes', 'Mostly', 'No']),
    T('What is missing from our toolchain?'),
  ]],
  ['Onboarding experience', 'For everyone who joined this year.', 14, [
    S('How was your first week overall?', RATE),
    S('Did you have your equipment on day one?', YESNO),
    S('Did you have accounts and access on day one?', YESNO),
    S('I knew who to ask when I was stuck.', AGREE),
    M('What helped most?', ['A buddy', 'Written docs', 'Recorded demos', 'Team lunch', 'Shadowing']),
    S('How long until you shipped something small?', ['First week', 'First month', 'First quarter', 'Still waiting']),
    S('The role matched what was described in interviews.', AGREE),
    S('How would you rate the onboarding documentation?', RATE),
    S('Did you meet your team in person in the first month?', YESNO),
    S('I would recommend us to a friend as a place to work.', AGREE),
    T('What would you change about onboarding?'),
  ]],
  ['Meeting load', 'Do we have too many? Probably.', -2, [
    S('How many hours a week do you spend in meetings?', ['Under two', 'Two to five', 'Five to ten', 'Over ten']),
    S('Most meetings I attend have a clear purpose.', AGREE),
    S('Could a third of them be a written update?', ['Yes', 'No', 'Some']),
    S('How often do meetings start late?', FREQ),
    S('How often do you multitask during meetings?', FREQ),
    M('Which recurring meetings are worth keeping?', ['Standup', 'Sprint planning', 'Retrospective', 'All hands', 'One to ones']),
    S('Do meetings usually end with clear owners?', ['Always', 'Usually', 'Rarely', 'Never']),
    S('Thirty minutes is a better default than sixty.', AGREE),
    S('Should we have a no-meeting day?', ['Yes', 'No', 'Half a day would do']),
    S('How would you rate our meeting notes?', RATE),
    T('Which recurring meeting would you cancel?'),
  ]],
  ['Learning and development', 'How to spend the budget before it expires.', 21, [
    M('What would you spend it on?', ['Conferences', 'Books', 'Online courses', 'Certifications', 'A mentor']),
    S('I have time during work hours to learn.', AGREE),
    S('How many days a quarter could you realistically use?', ['None', 'One', 'Two', 'Three or more']),
    S('Would you present what you learned to the team?', ['Yes', 'Maybe', 'No']),
    M('Which skills matter most for your role next year?', ['Backend', 'Frontend', 'Security', 'Data', 'Leadership', 'Design']),
    S('How would you rate the learning support you get today?', RATE),
    S('Internal talks are useful to me.', AGREE),
    S('Would you mentor someone junior?', ['Yes', 'No', 'With guidance']),
    S('Should the budget roll over if unused?', YESNO),
    S('How often do you read technical material for work?', FREQ),
    T('Name one course or conference you would pick.'),
  ]],
  ['Summer party', 'Date, place, and whether we do it at all.', 5, [
    S('Should we do a summer party?', YESNO),
    M('Which month works?', ['June', 'July', 'August', 'September']),
    S('Weekday evening or weekend?', ['Weekday evening', 'Weekend', 'No preference']),
    S('Bring partners?', ['Yes', 'No', 'No preference']),
    S('Would you travel up to an hour for it?', YESNO),
    M('What should it include?', ['Dinner', 'Music', 'Games', 'A short talk', 'Nothing formal']),
    S('Indoors or outdoors?', ['Indoors', 'Outdoors', 'Either']),
    S('There should be an alcohol-free option throughout.', AGREE),
    S('How long should it run?', ['Two hours', 'Three to four', 'All evening']),
    S('Would you help organise it?', ['Yes', 'No', 'Maybe']),
    T('Somewhere you would like it held?'),
  ]],
  ['Documentation health', 'Where the wiki is lying to us.', 30, [
    S('How trustworthy is our documentation?', ['Very', 'Somewhat', 'Not at all']),
    S('How often do you find what you are looking for?', FREQ),
    M('Which areas are worst?', ['Setup', 'Deployment', 'Architecture', 'Runbooks', 'Onboarding']),
    S('I know where to put a new document.', AGREE),
    S('How often do you write documentation?', FREQ),
    S('Search on the wiki works well.', AGREE),
    S('Should docs live next to the code instead?', ['Yes', 'No', 'For some things']),
    S('How out of date is the average page?', ['Current', 'A few months', 'A year or more', 'No idea']),
    S('Would a documentation day each quarter help?', YESNO),
    S('How would you rate our runbooks?', RATE),
    T('Name one page that needs rewriting.'),
  ]],
  ['Quarterly pulse', 'The short one. Sixty seconds.', 45, [
    S('How is your workload right now?', ['Too light', 'About right', 'Heavy', 'Unsustainable']),
    S('Do you know what is expected of you this quarter?', ['Yes', 'Roughly', 'No']),
    S('I get useful feedback on my work.', AGREE),
    S('I can raise a concern without worrying about it.', AGREE),
    S('How would you rate communication from leadership?', RATE),
    S('I understand how my work connects to company goals.', AGREE),
    S('How often do you feel stretched too thin?', FREQ),
    S('My manager is available when I need them.', AGREE),
    S('How likely are you to be here in a year?', ['Very likely', 'Likely', 'Unsure', 'Unlikely']),
    S('Do you have the tools to do your job well?', YESNO),
    T('One thing we should start doing?'),
  ]],
];

const QS = (question, options, correctAnswer) => ['Single', question, options, correctAnswer];
const QM = (question, options, correctAnswers) => ['Multiple', question, options, correctAnswers];

const QUIZZES = [
  ['Fire safety refresher', 'Annual, and mercifully short.', 7, [
    QS('Where is the assembly point?', ['The car park', 'The kitchen', 'The basement'], 0),
    QS('What do you do first when the alarm sounds?', ['Save your work', 'Leave immediately', 'Find your coat'], 1),
    QM('Which can you use on an electrical fire?', ['CO2 extinguisher', 'Water', 'Fire blanket'], [0, 2]),
    QS('Who checks that everyone is out?', ['Nobody', 'The fire warden', 'The last person'], 1),
    QS('May you use the lift during an evacuation?', YESNO, 1),
    QS('How often is the alarm tested?', ['Weekly', 'Monthly', 'Yearly'], 0),
    QS('You see a blocked fire exit. You:', ['Ignore it', 'Report it', 'Move it and say nothing'], 1),
    QM('What does a fire need to burn?', ['Heat', 'Fuel', 'Oxygen', 'Smoke'], [0, 1, 2]),
    QS('Smoke fills the corridor. You:', ['Run through upright', 'Stay low', 'Wait in the room'], 1),
    QS('When may you re-enter the building?', ['When the alarm stops', 'When the warden says so', 'After five minutes'], 1),
  ]],
  ['Data protection basics', 'What we may and may not keep.', 12, [
    QS('Can you email a customer list to your personal address?', YESNO, 1),
    QS('How long may we keep an applicant CV?', ['Forever', 'Six months', 'Until they ask'], 1),
    QM('Which of these are personal data?', ['Home address', 'Office floor number', 'Private phone number'], [0, 2]),
    QS('Who do you tell first about a suspected breach?', ['Nobody', 'Your manager', 'The customer'], 1),
    QS('How long to report a serious breach?', ['24 hours', '72 hours', 'One week'], 1),
    QS('A customer asks for all data we hold. That is:', ['A complaint', 'A subject access request', 'Not allowed'], 1),
    QM('Which are lawful bases for processing?', ['Consent', 'Contract', 'Curiosity'], [0, 1]),
    QS('May you keep test data copied from production?', ['Yes', 'No', 'Only if anonymised'], 2),
    QS('Where should customer files be stored?', ['Your desktop', 'The approved system', 'A personal drive'], 1),
    QS('Someone asks to be deleted. Backups:', ['Are exempt forever', 'Are handled by policy', 'Do not exist'], 1),
  ]],
  ['Security awareness', 'Phishing, passwords, and locked screens.', -3, [
    QS('An email demands urgent gift cards. You:', ['Buy them', 'Verify by phone', 'Reply asking why'], 1),
    QS('Where should a password live?', ['A sticky note', 'A password manager', 'A spreadsheet'], 1),
    QM('Which make a password stronger?', ['Length', 'Reuse across sites', 'A passphrase'], [0, 2]),
    QS('You leave your desk for five minutes. You:', ['Lock the screen', 'Leave it', 'Turn the monitor off'], 0),
    QS('A caller claims to be IT and wants your code. You:', ['Give it', 'Refuse and report', 'Ask them to call back'], 1),
    QS('What does two-factor protect against?', ['Slow internet', 'A stolen password', 'Spam arriving'], 1),
    QM('Signs of a phishing email?', ['Urgency', 'Mismatched sender domain', 'Correct spelling of your name'], [0, 1]),
    QS('You find a USB stick in the car park. You:', ['Plug it in', 'Hand it to IT', 'Take it home'], 1),
    QS('Is public wifi safe for admin work?', ['Yes', 'No', 'Only with the VPN'], 2),
    QS('You clicked a bad link. You:', ['Say nothing', 'Report it immediately', 'Wait and see'], 1),
  ]],
  ['Product knowledge', 'Can you answer what a customer asks?', 3, [
    QS('Which plan includes priority support?', ['Free', 'Team', 'Enterprise'], 2),
    QS('How long is the trial?', ['7 days', '14 days', '30 days'], 1),
    QM('Which integrations ship today?', ['Calendar', 'Payroll', 'Single sign-on'], [0, 2]),
    QS('Where does customer data live?', ['United States', 'European Union', 'Both'], 1),
    QS('Can a company have more than one admin?', YESNO, 0),
    QS('What happens to answers when a survey closes?', ['Deleted', 'Kept and visible to admins', 'Exported automatically'], 1),
    QS('Who can see an individual quiz score?', ['Everyone', 'Admins and moderators', 'Nobody'], 1),
    QM('Which can a member do without approval?', ['Write notes', 'Ban a colleague', 'Vote on a meeting'], [0, 2]),
    QS('How are meeting times shown across time zones?', ['Always UTC', 'In the reader time zone', 'In the creator time zone'], 1),
    QS('What happens to content when a company closes?', ['Kept forever', 'Deleted after seven days', 'Archived publicly'], 1),
  ]],
  ['Accessibility essentials', 'Building things everyone can use.', 18, [
    QS('Minimum contrast for body text?', ['2:1', '4.5:1', '10:1'], 1),
    QS('Is colour alone enough to show an error?', YESNO, 1),
    QM('Which help a screen reader?', ['Alt text', 'Semantic headings', 'Placeholder-only labels'], [0, 1]),
    QS('Smallest comfortable touch target?', ['24px', '48px', '72px'], 1),
    QS('Every input needs:', ['A placeholder', 'A visible label', 'A tooltip'], 1),
    QS('Keyboard access should reach:', ['Every control', 'Only forms', 'Nothing in particular'], 0),
    QM('Which break screen readers?', ['Images with no alt', 'Correct heading order', 'A div used as a button'], [0, 2]),
    QS('What does a focus ring do?', ['Decoration', 'Shows keyboard position', 'Nothing'], 1),
    QS('Captions on video are for:', ['Deaf users only', 'Anyone in a noisy place too', 'Search engines'], 1),
    QS('Animation that cannot be turned off is:', ['Fine', 'A problem for some users', 'Required'], 1),
  ]],
  ['Code review standards', 'What we expect in a review.', 25, [
    QS('What is the first thing to check?', ['Formatting', 'Whether it is correct', 'Variable names'], 1),
    QM('Which comments are worth leaving?', ['A real defect', 'A nit the formatter handles', 'A simpler approach'], [0, 2]),
    QS('When may you approve without running it?', ['Always', 'When tests cover it', 'Never'], 1),
    QS('A review with no comments means:', ['You skimmed it', 'It may genuinely be fine', 'It is perfect'], 1),
    QS('How large should a pull request be?', ['As large as possible', 'Small enough to read carefully', 'One file'], 1),
    QM('What blocks a merge?', ['A failing test', 'A style preference', 'A security hole'], [0, 2]),
    QS('You disagree with the author. You:', ['Merge anyway', 'Explain and discuss', 'Reject silently'], 1),
    QS('Who is responsible after a bad merge?', ['The author alone', 'The reviewer alone', 'Both'], 2),
    QS('A test was deleted to make CI pass. That is:', ['Fine', 'A blocker', 'Up to the author'], 1),
    QS('Best time to review?', ['End of sprint', 'Same day', 'When asked twice'], 1),
  ]],
  ['Expense policy', 'Before you book the flight.', -8, [
    QS('What needs a receipt?', ['Everything', 'Over 25', 'Nothing'], 1),
    QS('Who approves travel?', ['Nobody', 'Your manager', 'Finance'], 1),
    QM('Which are reimbursable?', ['Client dinner', 'Parking fine', 'Train fare'], [0, 2]),
    QS('How long do you have to submit?', ['One week', 'One month', 'One year'], 1),
    QS('Booking class for a two-hour flight?', ['Economy', 'Business', 'Your choice'], 0),
    QS('Can you expense a colleague meal without approval?', ['Yes', 'No', 'Under 50'], 1),
    QM('Which need approval in advance?', ['Conference tickets', 'Coffee', 'Hotel over three nights'], [0, 2]),
    QS('Personal days added to a work trip are:', ['Covered', 'Yours to pay', 'Not allowed'], 1),
    QS('Lost receipt. You:', ['Claim anyway', 'Declare it and explain', 'Skip the claim'], 1),
    QS('Currency for a foreign expense?', ['Always euro', 'As paid, converted on the day', 'Your choice'], 1),
  ]],
  ['Incident response', 'The first fifteen minutes.', 10, [
    QS('What comes first?', ['Find the cause', 'Stop the bleeding', 'Write the postmortem'], 1),
    QS('Who declares an incident?', ['Only managers', 'Anyone who sees one', 'The on-call engineer alone'], 1),
    QM('What belongs in the first update?', ['What is broken', 'Who is to blame', 'What you are doing'], [0, 2]),
    QS('When is a postmortem blameless?', ['Never', 'Always', 'When it was nobody in particular'], 1),
    QS('Who talks to customers during an incident?', ['Everyone', 'One named person', 'Nobody'], 1),
    QS('How often should you post updates?', ['When it is fixed', 'On a regular cadence', 'Only if asked'], 1),
    QM('Which are severity-one signals?', ['Total outage', 'Data loss', 'A typo in the footer'], [0, 1]),
    QS('The fix is risky and it is 2am. You:', ['Ship it alone', 'Get a second pair of eyes', 'Always wait for morning'], 1),
    QS('Who owns the timeline afterwards?', ['Nobody', 'The incident lead', 'The newest joiner'], 1),
    QS('An action item with no owner is:', ['Fine', 'Not an action item', 'For the manager'], 1),
  ]],
  ['Customer support tone', 'How we write when it has gone wrong.', 40, [
    QS('A customer is angry and right. You:', ['Defend the policy', 'Apologise and fix it', 'Escalate silently'], 1),
    QS('Best opening for a delay?', ['Sorry for any inconvenience', 'What happened and when it is fixed', 'Our team is working hard'], 1),
    QM('Which to avoid?', ['Jargon', 'Plain language', 'Blaming another team'], [0, 2]),
    QS('You do not know the answer. You:', ['Guess', 'Say so and find out', 'Ignore the message'], 1),
    QS('How soon should a first reply go out?', ['Within the hour', 'Within a day', 'When solved'], 0),
    QS('A refund is outside policy. You:', ['Refuse flatly', 'Explain and offer what you can', 'Ignore it'], 1),
    QM('Which build trust?', ['Specific timelines', 'Vague reassurance', 'Following up when promised'], [0, 2]),
    QS('Should you use the customer name?', ['Never', 'Where it reads naturally', 'In every sentence'], 1),
    QS('The bug is their mistake. You:', ['Say so bluntly', 'Show them the fix kindly', 'Close the ticket'], 1),
    QS('Closing a ticket without confirmation is:', ['Efficient', 'Premature', 'Required'], 1),
  ]],
  ['Company handbook', 'The bits people actually need.', 60, [
    QS('How much notice for annual leave?', ['None', 'Two weeks', 'Two months'], 1),
    QS('Who do you tell if you are sick?', ['Nobody', 'Your manager', 'HR only'], 1),
    QM('Which are paid?', ['Annual leave', 'Unpaid sabbatical', 'Public holidays'], [0, 2]),
    QS('Where is the handbook kept?', ['The wiki', 'Email', 'Nowhere'], 0),
    QS('Probation length?', ['One month', 'Three months', 'A year'], 1),
    QS('Can you carry leave into next year?', ['All of it', 'A limited amount', 'None'], 1),
    QS('Who approves a role change?', ['Anyone', 'Your manager and HR', 'Nobody'], 1),
    QM('Which count as working time?', ['Travel to a client', 'Your commute', 'Training days'], [0, 2]),
    QS('Notice period after probation?', ['One week', 'One month', 'Six months'], 1),
    QS('Where do you report a concern about conduct?', ['Nowhere', 'Your manager or HR', 'Social media'], 1),
  ]],
];

const MEETINGS = [
  ['Quarterly planning', 'Goals, headcount and what we drop.', 12, [[14, 9, 2], [14, 14, 2], [15, 9, 2]], 0],
  ['Design review: onboarding', 'Walk through the new first-run flow.', 4, [[5, 11, 1], [5, 15, 1], [6, 10, 1]], null],
  ['Retrospective', 'What went badly, and what we change.', 2, [[3, 16, 1], [4, 16, 1]], null],
  ['All hands', 'Numbers, roadmap, questions.', 8, [[10, 10, 1], [10, 15, 1], [11, 10, 1], [11, 15, 1]], 1],
  ['Budget sign-off', 'Finance needs an answer this month.', 6, [[7, 9, 1], [7, 13, 1], [8, 11, 1]], null],
  ['Hiring loop debrief', 'Two candidates, one slot.', 1, [[2, 9, 1], [2, 13, 1]], null],
  ['Security walkthrough', 'Rules, App Check and what is still open.', 16, [[18, 10, 2], [19, 10, 2], [20, 14, 2]], null],
  ['Customer advisory call', 'Three customers, thirty minutes each.', 20, [[22, 9, 3], [23, 9, 3]], 0],
  ['Offsite planning', 'Where, when, and who books it.', -4, [[-1, 10, 2], [-1, 14, 2]], null],
  ['Roadmap sync', 'Line up engineering and sales.', 28, [[30, 9, 1], [30, 14, 1], [31, 9, 1], [31, 14, 1], [32, 11, 1]], null],
];

function publicQuestion([type, question, options]) {
  return type === 'Text' ? { type, question } : { type, question, options };
}

function answerKey([type, , , correct]) {
  if (type === 'Single') return { type, correctAnswer: correct };
  if (type === 'Multiple') return { type, correctAnswers: correct };
  return { type };
}

function assertShapes() {
  const problems = [];
  for (const [name, , , questions] of [...SURVEYS, ...QUIZZES]) {
    if (questions.length < 10) {
      problems.push(`${name} has only ${questions.length} questions`);
    }
    for (const [type, text, options] of questions) {
      if (type !== 'Text' && (!options || options.length < 2)) {
        problems.push(`${name}: "${text}" needs at least two options`);
      }
      if (options) {
        const unique = new Set(options.map((option) => option.trim().toLowerCase()));
        if (unique.size !== options.length) {
          problems.push(`${name}: "${text}" has duplicate options`);
        }
      }
    }
  }
  for (const [name, , , questions] of QUIZZES) {
    for (const [type, text, options, correct] of questions) {
      const indexes = type === 'Multiple' ? correct : [correct];
      if (!Array.isArray(indexes) || indexes.some((value) => typeof value !== 'number')) {
        problems.push(`${name}: "${text}" has no marked answer`);
        continue;
      }
      if (type === 'Multiple' && indexes.length < 2) {
        problems.push(`${name}: "${text}" is multiple choice with one answer`);
      }
      if (indexes.some((value) => value < 0 || value >= options.length)) {
        problems.push(`${name}: "${text}" marks an option that does not exist`);
      }
    }
  }
  if (problems.length) {
    throw new Error(['Seed data is invalid:', ...problems.map((p) => `  ${p}`)].join('\n'));
  }
}

async function resolveTarget() {
  const args = process.argv.slice(2).filter((value) => !value.startsWith('--'));
  const wanted = args[0];
  const explicitAuthor = args[1];

  const companies = await firestore().collection('companies').get();
  if (companies.empty) {
    throw new Error('No company exists yet. Register and create one first.');
  }

  const named = (doc) => String(doc.data().name ?? '').trim();
  const match = wanted
    ? companies.docs.find(
        (doc) => doc.id === wanted || named(doc).toLowerCase() === wanted.toLowerCase(),
      )
    : companies.docs.length === 1
      ? companies.docs[0]
      : undefined;

  if (!match) {
    const list = companies.docs
      .map((doc) => `  ${named(doc) || '(unnamed)'}  ->  ${doc.id}`)
      .join('\n');
    throw new Error(
      [
        wanted ? `No company called "${wanted}".` : 'More than one company exists.',
        'Pick one:',
        list,
        '',
        '  node ../tool/seed_demo_content.js "<company name or id>"',
      ].join('\n'),
    );
  }

  const companyId = match.id;
  const companyName = named(match) || companyId;
  if (explicitAuthor) return { companyId, companyName, createdBy: explicitAuthor };

  const staff = await firestore()
    .collection('memberDirectory')
    .where('companyId', '==', companyId)
    .where('membership', '==', 'active')
    .get();
  const author = staff.docs.find((doc) =>
    ['admin', 'superadmin', 'moderator'].includes(doc.data().role),
  );
  if (!author) {
    throw new Error(
      `No active admin found in "${companyName}". Pass a user id as the second argument.`,
    );
  }
  return { companyId, companyName, createdBy: author.id };
}

function preview() {
  const when = (days) => new Date(at(days, 17)).toDateString();

  console.log('');
  console.log('DRY RUN - nothing will be written.');
  console.log('');
  console.log(`Surveys (${SURVEYS.length})`);
  for (const [name, , days, questions] of SURVEYS) {
    console.log(`  ${name} - ${questions.length} questions - closes ${when(days)}`);
  }
  console.log('');
  console.log(`Quizzes (${QUIZZES.length})`);
  for (const [name, , days, questions] of QUIZZES) {
    console.log(`  ${name} - ${questions.length} questions - closes ${when(days)}`);
  }
  console.log('');
  console.log(`Meetings (${MEETINGS.length})`);
  for (const [title, , days, slots, confirmed] of MEETINGS) {
    const state = confirmed === null ? 'open for votes' : 'time confirmed';
    console.log(`  ${title} - ${slots.length} slots - ${state} - voting ends ${when(days)}`);
  }
  console.log('');
  console.log('Run again without --dry-run to write them.');
}

async function main() {
  assertShapes();

  const named = process.argv.slice(2).filter((value) => !value.startsWith('--'));
  if (DRY_RUN && named.length === 0) {
    preview();
    return;
  }

  const { companyId, companyName, createdBy } = await resolveTarget();
  console.log(`Target company: "${companyName}" (${companyId})`);
  console.log(`Authored by:    ${createdBy}`);

  if (DRY_RUN) {
    preview();
    return;
  }

  const now = Timestamp.now();
  let batch = firestore().batch();
  let queued = 0;

  const commit = async () => {
    if (queued === 0) return;
    await batch.commit();
    batch = firestore().batch();
    queued = 0;
  };

  const write = async (ref, data) => {
    batch.set(ref, data);
    queued += 1;
    if (queued >= 200) await commit();
  };

  let index = 0;
  for (const [name, description, deadlineDays, questions] of SURVEYS) {
    const id = `${PREFIX}survey-${String(++index).padStart(2, '0')}`;
    await write(firestore().collection('surveys').doc(id), {
      surveyName: name,
      surveyDescription: description,
      timeCreated: now,
      questions: questions.map(publicQuestion),
      id,
      participants: [],
      deadline: Timestamp.fromMillis(at(deadlineDays, 17)),
      timeLimitPerQuestion: 0,
      surveyType: 0,
      companyId,
      createdBy,
      responsesRevision: 0,
    });
  }

  index = 0;
  for (const [name, description, deadlineDays, questions] of QUIZZES) {
    const id = `${PREFIX}quiz-${String(++index).padStart(2, '0')}`;
    await write(firestore().collection('surveys').doc(id), {
      surveyName: name,
      surveyDescription: description,
      timeCreated: now,
      questions: questions.map(publicQuestion),
      id,
      participants: [],
      deadline: Timestamp.fromMillis(at(deadlineDays, 17)),
      timeLimitPerQuestion: 45,
      surveyType: 1,
      companyId,
      createdBy,
      responsesRevision: 0,
    });
    await write(firestore().collection('surveyAnswerKeys').doc(id), {
      schemaVersion: 1,
      surveyId: id,
      companyId,
      questionKeys: questions.map(answerKey),
    });
  }

  index = 0;
  for (const [title, description, closesDays, slotSpecs, confirmed] of MEETINGS) {
    const id = `${PREFIX}meeting-${String(++index).padStart(2, '0')}`;
    const slots = slotSpecs.map(([day, hour, hours], slot) => {
      const startAt = at(day, hour);
      return {
        slotId: `${id}-s${slot + 1}`,
        startAt: Timestamp.fromMillis(startAt),
        endAt: Timestamp.fromMillis(startAt + hours * HOUR),
      };
    });
    await write(firestore().collection('appointments').doc(id), {
      schemaVersion: 2,
      revision: 1,
      appointmentId: id,
      companyId,
      createdBy,
      title,
      description,
      zoneId: 'Europe/Berlin',
      expirationAt: Timestamp.fromMillis(at(closesDays, 12)),
      slots,
      slotIds: slots.map((slot) => slot.slotId),
      confirmedSlotId: confirmed === null ? null : slots[confirmed].slotId,
      participantUserIds: [],
      createdAt: now,
    });
  }

  await commit();
  console.log('');
  console.log(
    `Wrote ${SURVEYS.length} surveys, ${QUIZZES.length} quizzes, ${MEETINGS.length} meetings.`,
  );
  console.log(`Every id starts with "${PREFIX}". Remove them all with --clean.`);
}

async function clean() {
  let removed = 0;
  for (const collection of ['surveys', 'surveyAnswerKeys', 'appointments']) {
    const docs = await firestore().collection(collection).get();
    for (const doc of docs.docs.filter((entry) => entry.id.startsWith(PREFIX))) {
      const children = await doc.ref.collection('participants').get();
      for (const child of children.docs) await child.ref.delete();
      await doc.ref.delete();
      removed += 1;
    }
  }
  console.log(`Removed ${removed} seeded documents.`);
}

(process.argv.includes('--clean') ? clean() : main()).catch((error) => {
  console.error(String(error.message ?? error));
  process.exit(1);
});
