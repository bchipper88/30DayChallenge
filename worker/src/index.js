import { createClient } from '@supabase/supabase-js';
import OpenAI from 'openai';
import { randomUUID } from 'node:crypto';
import { writeFileSync } from 'node:fs';

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const openAIKey = process.env.OPENAI_API_KEY;
const pollIntervalMs = parseInt(process.env.POLL_INTERVAL_MS ?? '3000', 10);
const maxOpenAIRetries = parseInt(process.env.OPENAI_MAX_RETRIES ?? '2', 10);
const openAIModel = process.env.OPENAI_MODEL ?? 'gpt-4.1-mini';
const openAITemperature = parseFloat(process.env.OPENAI_TEMPERATURE ?? '0.6');
const fixedTemperatureModels = new Set(['gpt-4.1-mini', 'gpt-4.1-nano', 'gpt-4.1']);
const fallbackUserId = process.env.SUPABASE_FALLBACK_USER_ID ?? null;
const staleJobRetrySeconds = Number.isFinite(parseInt(process.env.STALE_JOB_RETRY_SECONDS ?? '', 10))
  ? parseInt(process.env.STALE_JOB_RETRY_SECONDS ?? '', 10)
  : 300;
const staleJobCheckIntervalMs = Number.isFinite(parseInt(process.env.STALE_JOB_CHECK_INTERVAL_MS ?? '', 10))
  ? parseInt(process.env.STALE_JOB_CHECK_INTERVAL_MS ?? '', 10)
  : 60_000;

const modelRequiresFixedTemperature = (model) => {
  if (!model) return false;
  if (fixedTemperatureModels.has(model)) {
    return true;
  }
  return model.startsWith('gpt-5');
};

if (!supabaseUrl || !supabaseKey) {
  console.error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be provided.');
  process.exit(1);
}

if (!openAIKey) {
  console.error('OPENAI_API_KEY must be provided.');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: { persistSession: false }
});
const openai = new OpenAI({ apiKey: openAIKey });

let lastStaleJobCheck = 0;

const blueprintSchema = {
  type: 'object',
  additionalProperties: false,
  required: [
    'title',
    'domain',
    'primaryGoal',
    'targetOutcome',
    'assumptions',
    'constraints',
    'resources',
    'purpose',
    'keyPrinciples',
    'riskRadar',
    'callToAction',
    'reminder',
    'celebrationRule',
    'streakRule',
    'accentPalette',
    'cardPalette',
    'milestones',
    'phases',
    'dailyPlan',
    'weeklyReviews'
  ],
  properties: {
    title: { type: 'string' },
    domain: {
      type: 'string',
      enum: [
        'fitness',
        'business',
        'learning',
        'creative',
        'productivity',
        'finance',
        'wellbeing',
        'other'
      ]
    },
    primaryGoal: { type: 'string' },
    targetOutcome: {
      type: 'object',
      additionalProperties: false,
      required: ['metric', 'value', 'unit', 'timeframe'],
      properties: {
        metric: { type: 'string' },
        value: { type: 'number' },
        unit: { type: 'string' },
        timeframe: { type: 'string' }
      }
    },
    assumptions: {
      type: 'array',
      minItems: 2,
      items: { type: 'string' }
    },
    constraints: {
      type: 'array',
      minItems: 2,
      items: { type: 'string' }
    },
    resources: {
      type: 'array',
      minItems: 2,
      items: { type: 'string' }
    },
    purpose: {
      type: 'string'
    },
    keyPrinciples: {
      type: 'array',
      minItems: 3,
      maxItems: 5,
      items: { type: 'string' }
    },
    riskRadar: {
      type: 'array',
      minItems: 3,
      maxItems: 6,
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['risk', 'likelihood', 'mitigation'],
        properties: {
          risk: { type: 'string' },
          likelihood: { type: 'string', enum: ['low', 'medium', 'high'] },
          mitigation: { type: 'string' }
        }
      }
    },
    callToAction: { type: 'string' },
    reminder: {
      type: 'object',
      additionalProperties: false,
      required: ['hour', 'minute', 'message'],
      properties: {
        hour: { type: 'integer', minimum: 0, maximum: 23 },
        minute: { type: 'integer', minimum: 0, maximum: 59 },
        message: { type: 'string' }
      }
    },
    celebrationRule: {
      type: 'object',
      additionalProperties: false,
      required: ['trigger', 'message'],
      properties: {
        trigger: { type: 'string', enum: ['dayComplete', 'milestoneComplete'] },
        message: { type: 'string' }
      }
    },
    streakRule: {
      type: 'object',
      additionalProperties: false,
      required: ['thresholdMinutes', 'graceDays'],
      properties: {
        thresholdMinutes: { type: 'integer', minimum: 10, maximum: 180 },
        graceDays: { type: 'integer', minimum: 0, maximum: 5 }
      }
    },
    accentPalette: {
      type: 'array',
      minItems: 3,
      maxItems: 4,
      items: { type: 'string', pattern: '^#?[0-9A-Fa-f]{6}$' }
    },
    cardPalette: {
      type: 'array',
      minItems: 2,
      maxItems: 3,
      items: { type: 'string', pattern: '^#?[0-9A-Fa-f]{6}$' }
    },
    milestones: {
      type: 'array',
      minItems: 4,
      maxItems: 6,
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['id', 'title', 'description', 'targetDay'],
        properties: {
          id: { type: 'string' },
          title: { type: 'string' },
          description: { type: 'string' },
          targetDay: { type: 'integer', minimum: 1, maximum: 30 }
        }
      }
    },
    phases: {
      type: 'array',
      minItems: 4,
      maxItems: 4,
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['name', 'objective', 'milestones', 'keyPrinciples', 'risks'],
        properties: {
          name: { type: 'string' },
          objective: { type: 'string' },
          milestones: {
            type: 'array',
            minItems: 1,
            items: {
              type: 'object',
              additionalProperties: false,
              required: ['title', 'detail', 'targetDay'],
              properties: {
                title: { type: 'string' },
                detail: { type: 'string' },
                targetDay: { type: 'integer', minimum: 1, maximum: 30 }
              }
            }
          },
          keyPrinciples: {
            type: 'array',
            minItems: 2,
            maxItems: 3,
            items: { type: 'string' }
          },
          risks: {
            type: 'array',
            minItems: 2,
            maxItems: 4,
            items: {
              type: 'object',
              additionalProperties: false,
              required: ['risk', 'likelihood', 'mitigation'],
              properties: {
                risk: { type: 'string' },
                likelihood: { type: 'string', enum: ['low', 'medium', 'high'] },
                mitigation: { type: 'string' }
              }
            }
          }
        }
      }
    },
    dailyPlan: {
      type: 'array',
      minItems: 30,
      maxItems: 30,
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['dayNumber', 'theme', 'checkInPrompt', 'celebrationMessage', 'tasks'],
        properties: {
          dayNumber: { type: 'integer', minimum: 1, maximum: 30 },
          theme: { type: 'string' },
          checkInPrompt: { type: 'string' },
          celebrationMessage: { type: 'string' },
          tasks: {
            type: 'array',
            minItems: 2,
            items: {
              type: 'object',
              additionalProperties: false,
              required: ['title', 'expectedMinutes', 'details', 'milestoneId'],
              properties: {
                title: { type: 'string' },
                expectedMinutes: { type: 'integer', minimum: 10, maximum: 180 },
                details: { type: 'string' },
                milestoneId: { type: 'string' }
              }
            }
          }
        }
      }
    },
    weeklyReviews: {
      type: 'array',
      minItems: 4,
      maxItems: 4,
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['weekNumber', 'evidenceToCollect', 'reflectionQuestions', 'adaptationRules'],
        properties: {
          weekNumber: { type: 'integer', minimum: 1, maximum: 4 },
          evidenceToCollect: {
            type: 'array',
            minItems: 3,
            items: { type: 'string' }
          },
          reflectionQuestions: {
            type: 'array',
            minItems: 3,
            items: { type: 'string' }
          },
          adaptationRules: {
            type: 'array',
            minItems: 3,
            items: {
              type: 'object',
              additionalProperties: false,
              required: ['condition', 'response'],
              properties: {
                condition: { type: 'string' },
                response: { type: 'string' }
              }
            }
          }
        }
      }
    }
  }
};

const blueprintPrompt = `
You are an expert coach who designs science-informed 30-day challenges that move someone from their stated goal to completion.

Produce a JSON object that matches the "PlanBlueprint" format shown below. Your plan must:
• Outline exactly 4 phases (7-8 day spans) with objectives and 2-3 milestones each.
• Define challenge-wide "keyPrinciples" (3-5) and "riskRadar" entries (3-6, each with likelihood low/medium/high) capturing only the highest-leverage guidance for the full 30-day journey.
• Provide 4-6 milestones (epics) each with an id, title, energetic description, and targetDay showing when it should be achieved.
• Provide a "dailyPlan" array with exactly 30 entries (dayNumber 1..30) and each day containing 2-3 tasks. Tasks require: title, expectedMinutes, details (imperative description), and milestoneId referencing one of the milestones above. Add motivating checkInPrompt + celebrationMessage per day.
• Provide four weekly reviews (weekNumber 1..4) each with 3 evidence items, 3 reflection questions, and 3 adaptation rules (condition + response).
• Include assumptions, constraints, resources, callToAction, reminder (hour/minute/message), celebrationRule (trigger/message), streakRule (thresholdMinutes/graceDays), accentPalette (3-4 hex colors), and cardPalette (2-3 softer pastel hex colors for UI cards).
• Craft "callToAction" as an inspirational rally cry for their 30-day challenge—short, memorable, high-energy, and explicitly calling them to step up for the full journey.
• Map the provided user goal into the plan title, phases, and tasks with concrete, actionable language.

Return JSON in this exact structure (use your own values):
{
  "title": "Launch a mindful journaling app",
"domain": "wellbeing" // domain must be one of: fitness, business, learning, creative, productivity, finance, wellbeing, other,
  "primaryGoal": "...",
  "targetOutcome": { "metric": "Beta testers", "value": 25, "unit": "people", "timeframe": "30 days" },
  "assumptions": ["..."],
  "constraints": ["..."],
  "resources": ["..."],
  "purpose": "...",
  "keyPrinciples": ["..."],
  "riskRadar": [
    { "risk": "...", "likelihood": "medium", "mitigation": "..." }
  ],
  "callToAction": "...",
  "reminder": { "hour": 8, "minute": 30, "message": "..." },
  "celebrationRule": { "trigger": "dayComplete", "message": "..." },
  "streakRule": { "thresholdMinutes": 45, "graceDays": 2 },
  "accentPalette": ["#FF7EB3", "#A855F7", "#3B82F6"],
  "cardPalette": ["#FECACA", "#FBCFE8"],
  "phases": [
    {
      "name": "Phase name",
      "objective": "...",
      "milestones": [
        { "title": "Milestone", "detail": "...", "targetDay": 7 }
      ],
      "keyPrinciples": ["..."],
      "risks": [
        { "risk": "...", "likelihood": "medium", "mitigation": "..." }
      ]
    },
    "... total 4 phases ..."
  ],
  "milestones": [
    { "id": "M1", "title": "Ship MVP", "description": "Finish the core experience and ready it for beta.", "targetDay": 21 }
  ],
  "dailyPlan": [
    {
      "dayNumber": 1,
      "theme": "Ignite",
      "checkInPrompt": "...",
      "celebrationMessage": "...",
      "tasks": [
        {
          "title": "Define success metrics",
          "details": "Outline measurable success criteria.",
          "expectedMinutes": 45,
          "milestoneId": "M1"
        }
      ]
    }
    // ... entries up to dayNumber 30 ...
  ],
  "weeklyReviews": [
    {
      "weekNumber": 1,
      "evidenceToCollect": ["..."],
      "reflectionQuestions": ["..."],
      "adaptationRules": [
        { "condition": "If", "response": "Then" }
      ]
    }
  ]
}
Strictly return JSON only, no commentary.
`;

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function reserveJob() {
  await reviveStaleJobsIfNeeded();
  const { data: job, error } = await supabase
    .from('ai_generation_jobs')
    .select('*')
    .eq('status', 'pending')
    .order('created_at', { ascending: true })
    .limit(1)
    .maybeSingle();

  if (error) {
    console.error('Failed to select pending job', error);
    await sleep(pollIntervalMs);
    return null;
  }

  if (!job) {
    return null;
  }

  const { data: claimed, error: claimError } = await supabase
    .from('ai_generation_jobs')
    .update({ status: 'in_progress' })
    .eq('id', job.id)
    .eq('status', 'pending')
    .select('*')
    .maybeSingle();

  if (claimError) {
    console.error('Failed to claim job', claimError);
    return null;
  }

  if (!claimed) {
    console.log('Job already claimed elsewhere', { id: job.id });
    return null;
  }

  return claimed;
}

async function reviveStaleJobsIfNeeded() {
  const now = Date.now();
  if (now - lastStaleJobCheck < staleJobCheckIntervalMs) {
    return;
  }
  lastStaleJobCheck = now;

  if (!Number.isFinite(staleJobRetrySeconds) || staleJobRetrySeconds <= 0) {
    return;
  }

  const cutoff = new Date(now - staleJobRetrySeconds * 1000).toISOString();
  try {
    const { data, error } = await supabase
      .from('ai_generation_jobs')
      .update({ status: 'pending', error: null })
      .eq('status', 'in_progress')
      .lt('updated_at', cutoff)
      .select('id');

    if (error) {
      console.error('Failed to revive stale jobs', error);
      return;
    }

    if (data && data.length > 0) {
      console.warn('Revived stale jobs', { jobIds: data.map((item) => item.id) });
    }
  } catch (error) {
    console.error('Error reviving stale jobs', error);
  }
}

function buildPlanFromBlueprint(blueprint, { fallbackPurpose = null } = {}) {
  const normalizeString = (value, fallback = "") => {
    if (typeof value === "number" && Number.isFinite(value)) {
      return String(value);
    }
    if (typeof value === "string") {
      const trimmed = value.trim();
      return trimmed.length > 0 ? trimmed : fallback;
    }
    return fallback;
  };

  const normalizeInteger = (value, fallback = 0) => {
    const parsed = Number.parseInt(value, 10);
    return Number.isFinite(parsed) ? parsed : fallback;
  };

  const normalizeNumber = (value, fallback = 0) => {
    const parsed = Number.parseFloat(value);
    return Number.isFinite(parsed) ? parsed : fallback;
  };

  const normalizeLikelihood = (value) => {
    const lower = normalizeString(value).toLowerCase();
    return ['low', 'medium', 'high'].includes(lower) ? lower : 'medium';
  };

  const normalizeStringArray = (value, min = 0, max = Infinity) => {
    if (!Array.isArray(value)) return [];
    const result = [];
    for (const entry of value) {
      if (result.length === max) break;
      const text = normalizeString(entry);
      if (text.length > 0) {
        result.push(text);
      }
    }
    return result.length >= min ? result : result;
  };

  const phases = (Array.isArray(blueprint.phases) ? blueprint.phases : []).map((phase, index) => ({
    id: randomUUID(),
    index,
    name: normalizeString(phase.name, `Phase ${index + 1}`),
    objective: normalizeString(phase.objective, ""),
    milestones: (Array.isArray(phase.milestones) ? phase.milestones : []).map((milestone, milestoneIndex) => ({
      id: randomUUID(),
      title: normalizeString(milestone.title, `Milestone ${milestoneIndex + 1}`),
      detail: normalizeString(milestone.detail ?? milestone.description, ""),
      progress: 0,
      targetDay: normalizeInteger(milestone.targetDay, Math.min(30, ((index * 2) + milestoneIndex + 1) * 3))
    })),
    keyPrinciples: normalizeStringArray(phase.keyPrinciples),
    risks: (Array.isArray(phase.risks) ? phase.risks : []).map((risk) => ({
      id: randomUUID(),
      risk: normalizeString(risk.risk),
      likelihood: normalizeLikelihood(risk.likelihood),
      mitigation: normalizeString(risk.mitigation)
    }))
  }));

  const planPrinciples = [];
  const principleSeen = new Set();
  const enqueuePrinciple = (value) => {
    if (typeof value !== 'string') return;
    const trimmed = value.trim();
    if (!trimmed.length) return;
    const key = trimmed.toLowerCase();
    if (principleSeen.has(key)) return;
    principleSeen.add(key);
    planPrinciples.push(trimmed);
  };

  if (Array.isArray(blueprint.keyPrinciples)) {
    for (const entry of blueprint.keyPrinciples) {
      enqueuePrinciple(entry);
      if (planPrinciples.length === 5) break;
    }
  }

  if (planPrinciples.length < 3) {
    for (const phase of phases) {
      for (const principle of phase.keyPrinciples ?? []) {
        enqueuePrinciple(principle);
        if (planPrinciples.length === 5) break;
      }
      if (planPrinciples.length === 5) break;
    }
  }

  const planRisks = [];
  const riskSeen = new Set();
  const enqueueRisk = (risk) => {
    if (!risk || typeof risk !== 'object') return;
    const description = typeof risk.risk === 'string' ? risk.risk.trim() : '';
    const mitigation = typeof risk.mitigation === 'string' ? risk.mitigation.trim() : '';
    if (!description.length) return;
    const key = description.toLowerCase();
    if (riskSeen.has(key)) return;
    riskSeen.add(key);
    planRisks.push({
      id: randomUUID(),
      risk: description,
      likelihood: normalizeLikelihood(risk.likelihood),
      mitigation
    });
  };

  if (Array.isArray(blueprint.riskRadar)) {
    for (const risk of blueprint.riskRadar) {
      enqueueRisk(risk);
      if (planRisks.length === 6) break;
    }
  }

  if (planRisks.length < 3) {
    for (const phase of phases) {
      for (const risk of phase.risks ?? []) {
        enqueueRisk(risk);
        if (planRisks.length === 6) break;
      }
      if (planRisks.length === 6) break;
    }
  }

  const trimmedFallbackPurpose = typeof fallbackPurpose === 'string' ? fallbackPurpose.trim() : '';
  const blueprintPurpose = typeof blueprint.purpose === 'string' ? blueprint.purpose.trim() : '';
  const planPurpose = blueprintPurpose.length > 0 ? blueprintPurpose : (trimmedFallbackPurpose.length > 0 ? trimmedFallbackPurpose : null);

  let milestones = (Array.isArray(blueprint.milestones) ? blueprint.milestones : []).map((milestone, index) => ({
    id: normalizeString(milestone.id, `M-${index + 1}`),
    title: normalizeString(milestone.title, `Milestone ${index + 1}`),
    description: normalizeString(milestone.description ?? milestone.detail, ""),
    targetDay: normalizeInteger(milestone.targetDay, Math.min(30, (index + 1) * 6))
  }));

  if (milestones.length === 0) {
    milestones = [{
      id: 'M-1',
      title: 'Milestone 1',
      description: 'Reach your first meaningful checkpoint.',
      targetDay: 7
    }];
  }

  const milestoneIds = new Set(milestones.map((item) => item.id));

  const targetOutcomeSource = typeof blueprint.targetOutcome === "object" && blueprint.targetOutcome !== null ? blueprint.targetOutcome : {};
  const targetOutcome = {
    metric: normalizeString(targetOutcomeSource.metric, "Primary metric"),
    value: normalizeNumber(targetOutcomeSource.value, 0),
    unit: normalizeString(targetOutcomeSource.unit, "units"),
    timeframe: normalizeString(targetOutcomeSource.timeframe, "30 days")
  };

  const reminder = typeof blueprint.reminder === "object" && blueprint.reminder !== null ? blueprint.reminder : {};
  const reminderHour = normalizeInteger(reminder.hour, 8);
  const reminderMinute = normalizeInteger(reminder.minute, 30);
  const reminderMessage = normalizeString(reminder.message, "Take a focused moment for your challenge.");

  const celebration = typeof blueprint.celebrationRule === "object" && blueprint.celebrationRule !== null ? blueprint.celebrationRule : {};
  const celebrationTrigger = (() => {
    const value = normalizeString(celebration.trigger, "dayComplete").toLowerCase();
    return value === "milestonecomplete" ? "milestoneComplete" : "dayComplete";
  })();
  const celebrationMessage = normalizeString(celebration.message, "Great work—keep the streak alive!");

  const streak = typeof blueprint.streakRule === "object" && blueprint.streakRule !== null ? blueprint.streakRule : {};
  const streakThreshold = normalizeInteger(streak.thresholdMinutes, 45);
  const streakGrace = normalizeInteger(streak.graceDays, 2);

  let days = (Array.isArray(blueprint.dailyPlan) ? blueprint.dailyPlan : []).map((day, index) => ({
    id: randomUUID(),
    dayNumber: normalizeInteger(day.dayNumber, index + 1),
    theme: normalizeString(day.theme, `Focus Day ${index + 1}`),
    checkInPrompt: normalizeString(day.checkInPrompt),
    celebrationMessage: normalizeString(day.celebrationMessage),
    tasks: (day.tasks ?? []).map((task, taskIndex) => ({
      id: randomUUID(),
      title: normalizeString(task.title, `Task ${taskIndex + 1}`),
      expectedMinutes: normalizeInteger(task.expectedMinutes, 30),
      details: normalizeString(task.details),
      milestoneId: (() => {
        const raw = normalizeString(task.milestoneId);
        if (milestoneIds.has(raw)) return raw;
        return milestones[0]?.id ?? null;
      })(),
      isComplete: false
    }))
  }));

  if (days.length < 30) {
    const startIndex = days.length;
    for (let i = startIndex; i < 30; i += 1) {
      days.push({
        id: randomUUID(),
        dayNumber: i + 1,
        theme: `Momentum Day ${i + 1}`,
        checkInPrompt: "What did you move forward today?",
        celebrationMessage: "Notched another day—keep that fire going!",
        tasks: [
          {
            id: randomUUID(),
            title: "Plan your next focused action",
            expectedMinutes: 30,
            details: "Identify and execute the most impactful task for today.",
            milestoneId: milestones[0]?.id ?? null,
            isComplete: false
          }
        ]
      });
    }
  }

  let weeklyReviews = (Array.isArray(blueprint.weeklyReviews) ? blueprint.weeklyReviews : []).map((review, index) => ({
    id: randomUUID(),
    weekNumber: normalizeInteger(review.weekNumber, index + 1),
    evidenceToCollect: normalizeStringArray(review.evidenceToCollect),
    reflectionQuestions: normalizeStringArray(review.reflectionQuestions),
    adaptationRules: (Array.isArray(review.adaptationRules) ? review.adaptationRules : []).map((rule) => ({
      id: randomUUID(),
      condition: normalizeString(rule.condition),
      response: normalizeString(rule.response)
    }))
  }));

  const defaultAdaptation = () => ({
    id: randomUUID(),
    condition: "If momentum dips for two days",
    response: "Reduce scope and schedule a 15-minute booster session."
  });

  const ensureEntries = (entry, fallback) => (entry.length > 0 ? entry : [fallback]);

  weeklyReviews = weeklyReviews.map((review) => ({
    ...review,
    evidenceToCollect: ensureEntries(review.evidenceToCollect, "Capture one tangible proof of progress."),
    reflectionQuestions: ensureEntries(review.reflectionQuestions, "What worked best this week and why?"),
    adaptationRules: review.adaptationRules.length > 0 ? review.adaptationRules : [defaultAdaptation()]
  }));

  if (weeklyReviews.length < 4) {
    const startIndex = weeklyReviews.length;
    for (let i = startIndex; i < 4; i += 1) {
      weeklyReviews.push({
        id: randomUUID(),
        weekNumber: i + 1,
        evidenceToCollect: ["Document a meaningful outcome you created."],
        reflectionQuestions: ["Where did you see the biggest shift?"],
        adaptationRules: [defaultAdaptation()]
      });
    }
  }

  const accentPalette = (Array.isArray(blueprint.accentPalette) ? blueprint.accentPalette : ["#FF7EB3", "#A855F7", "#3B82F6"]).map((hex) => normalizeString(hex, "#3B82F6"));
  const cardPaletteSource = Array.isArray(blueprint.cardPalette) ? blueprint.cardPalette : accentPalette.slice(0, 2);
  const cardPalette = cardPaletteSource.length > 0 ? cardPaletteSource : accentPalette.slice(0, 2);

  const allowedDomains = ['fitness', 'business', 'learning', 'creative', 'productivity', 'finance', 'wellbeing', 'other'];
  const domainLower = normalizeString(blueprint.domain, 'other').toLowerCase();
  const domain = allowedDomains.includes(domainLower) ? domainLower : 'other';

  const callToAction = normalizeString(blueprint.callToAction, "This is your 30-day commitment—make every day count!");

  return {
    id: randomUUID(),
    title: normalizeString(blueprint.title, "30-Day Challenge"),
    domain,
    primaryGoal: normalizeString(blueprint.primaryGoal, ""),
    createdAt: new Date().toISOString(),
    summary: blueprint.summary ?? null,
    targetOutcome,
    assumptions: normalizeStringArray(blueprint.assumptions),
    constraints: normalizeStringArray(blueprint.constraints),
    resources: normalizeStringArray(blueprint.resources),
    purpose: planPurpose,
    keyPrinciples: planPrinciples,
    riskHighlights: planRisks,
    milestones,
    phases,
    days,
    weeklyReviews,
    reminderRule: {
      timeOfDay: {
        hour: reminderHour,
        minute: reminderMinute
      },
      message: reminderMessage
    },
    celebrationRule: {
      trigger: celebrationTrigger,
      message: celebrationMessage
    },
    streakRule: {
      thresholdMinutes: streakThreshold,
      graceDays: streakGrace
    },
    callToAction,
    accentPalette: {
      stops: accentPalette.map((hex) => ({ hex, opacity: 1 }))
    },
    cardPalette: {
      stops: cardPalette.map((hex) => ({ hex, opacity: 1 }))
    }
  };
}

async function generatePlan(prompt, modelOverride, purpose, familiarity) {
  const modelToUse = modelOverride ?? openAIModel;
  console.log('Reserve job payload model override', { modelOverride, modelToUse });
  let lastError;
  for (let attempt = 0; attempt <= maxOpenAIRetries; attempt += 1) {
    try {
      console.log('Requesting plan from OpenAI', {
        attempt: attempt + 1,
        promptLength: prompt.length,
        model: modelToUse,
      });
      const contextSections = [
        prompt,
        purpose ? `Purpose for this goal: ${purpose}` : null,
        familiarity ? `User familiarity level: ${familiarity}` : null,
      ].filter(Boolean);

      const requestPayload = {
        model: modelToUse,
        response_format: {
          type: 'json_schema',
          json_schema: {
            name: 'ChallengePlanBlueprint',
            schema: blueprintSchema,
            strict: true
          }
        },
        messages: [
          { role: 'system', content: blueprintPrompt },
          { role: 'user', content: contextSections.join('\n\n') }
        ]
      };

      if (!modelRequiresFixedTemperature(modelToUse)) {
        requestPayload.temperature = Number.isFinite(openAITemperature) ? openAITemperature : 0.6;
      }

      const completion = await openai.chat.completions.create(requestPayload);

      const message = completion.choices?.[0]?.message;
      if (!message) {
        throw new Error('OpenAI response missing message content');
      }

      const parseJson = (value) => {
        if (typeof value === 'string') {
          return JSON.parse(value);
        }
        return value;
      };

      let blueprint = null;
      const content = message.content;
      if (Array.isArray(content)) {
        for (const part of content) {
          if (part && typeof part === 'object') {
            if ('json' in part && part.json) {
              blueprint = parseJson(part.json);
              break;
            }
            if ('text' in part && typeof part.text === 'string' && part.text.trim().length > 0) {
              blueprint = parseJson(part.text);
              break;
            }
          } else if (typeof part === 'string' && part.trim().length > 0) {
            blueprint = parseJson(part);
            break;
          }
        }
      } else if (typeof content === 'string' && content.trim().length > 0) {
        blueprint = parseJson(content);
      }

      if (!blueprint) {
        throw new Error('OpenAI returned empty content');
      }

      const plan = buildPlanFromBlueprint(blueprint, { fallbackPurpose: purpose });
      return { plan, responseId: completion.id ?? null };
    } catch (error) {
      lastError = error;
      console.error('OpenAI request failed', { attempt: attempt + 1, error });
      if (attempt === maxOpenAIRetries) {
        throw error;
      }
      await sleep(1000 * (attempt + 1));
    }
  }

  throw lastError ?? new Error('Failed to request plan');
}

async function processJob(job) {
  try {
    const { plan, responseId } = await generatePlan(
      job.prompt,
      job.model ?? null,
      job.purpose ?? '',
      job.familiarity ?? ''
    );
    if (job.agent) {
      plan.craftedByAgent = job.agent;
    }

    const sanitizedPlan = JSON.parse(JSON.stringify(plan));

    try {
      writeFileSync('response.json', JSON.stringify({ jobId: job.id, plan: sanitizedPlan }, null, 2));
    } catch (writeError) {
      console.warn('Failed to write response.json for debugging', writeError);
    }

    console.log('Generated plan payload', JSON.stringify({ jobId: job.id, plan: sanitizedPlan }, null, 2));
    const { data: updatedRows, error: updateError } = await supabase
      .from('ai_generation_jobs')
      .update({
        status: 'completed',
        result: sanitizedPlan,
        response_id: responseId ?? null,
        error: null
      })
      .eq('id', job.id)
      .select('id, status')
      .maybeSingle();

    if (updateError || !updatedRows) {
      console.error('Failed to mark job completed', updateError ?? new Error('No row updated'));
      await supabase
        .from('ai_generation_jobs')
        .update({
          status: 'failed',
          error: (updateError?.message ?? 'Unable to persist plan result'),
          result: null
        })
        .eq('id', job.id);
      return;
    }

    console.log('Job completed', { id: job.id, model: job.model ?? openAIModel });

    const upsertUserId = job.user_id ?? fallbackUserId;
    if (upsertUserId) {
      const { error: planUpsertError } = await supabase
        .from('challenge_plans')
        .upsert({
          id: sanitizedPlan.id,
          user_id: upsertUserId,
          payload: sanitizedPlan
        }, { onConflict: 'id' });

      if (planUpsertError) {
        console.error('Failed to upsert challenge plan payload', planUpsertError);
      }
    } else {
      console.warn('Plan generated without associated user_id; skipping persistence to challenge_plans', { jobId: job.id });
    }
  } catch (error) {
    console.error('Job failed', { id: job.id, error });
    await supabase
      .from('ai_generation_jobs')
      .update({
        status: 'failed',
        error: error instanceof Error ? error.message : 'Unknown error',
        result: null
      })
      .eq('id', job.id);
  }
}

async function main() {
  console.log('AI plan worker started.');
  while (true) {
    try {
      const job = await reserveJob();
      if (!job) {
        await sleep(pollIntervalMs);
        continue;
      }

      await processJob(job);
    } catch (error) {
      console.error('Worker loop error', error);
      await sleep(pollIntervalMs);
    }
  }
}

main().catch((error) => {
  console.error('Worker terminated unexpectedly', error);
  process.exit(1);
});
