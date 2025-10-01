import { createClient } from '@supabase/supabase-js';
import OpenAI from 'openai';
import { randomUUID } from 'node:crypto';

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const openAIKey = process.env.OPENAI_API_KEY;
const pollIntervalMs = parseInt(process.env.POLL_INTERVAL_MS ?? '3000', 10);
const maxOpenAIRetries = parseInt(process.env.OPENAI_MAX_RETRIES ?? '2', 10);
const openAIModel = process.env.OPENAI_MODEL ?? 'gpt-4.1-mini';
const openAITemperature = parseFloat(process.env.OPENAI_TEMPERATURE ?? '0.6');
const fixedTemperatureModels = new Set(['gpt-4.1-mini', 'gpt-4.1-nano', 'gpt-4.1']);

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
              required: [
                'title',
                'type',
                'expectedMinutes',
                'instructions',
                'definitionOfDone',
                'tags',
                'metric'
              ],
              properties: {
                title: { type: 'string' },
                type: {
                  type: 'string',
                  enum: [
                    'setup',
                    'research',
                    'practice',
                    'review',
                    'reflection',
                    'outreach',
                    'build',
                    'ship'
                  ]
                },
                expectedMinutes: { type: 'integer', minimum: 10, maximum: 180 },
                instructions: { type: 'string' },
                definitionOfDone: { type: 'string' },
                tags: {
                  type: 'array',
                  minItems: 2,
                  items: { type: 'string' }
                },
                metric: {
                  anyOf: [
                    {
                      type: 'object',
                      additionalProperties: false,
                      required: ['name', 'unit', 'target'],
                      properties: {
                        name: { type: 'string' },
                        unit: { type: 'string' },
                        target: { type: 'number' }
                      }
                    },
                    { type: 'null' }
                  ]
                }
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
• Provide a "dailyPlan" array with exactly 30 entries (dayNumber 1..30) and each day containing 2-3 tasks. Tasks require: title, type (setup/research/practice/review/reflection/outreach/build/ship), expectedMinutes, instructions (imperative), definitionOfDone, tags (2-3), and metric {name, unit, target} (set metric to null when not applicable). Add motivating checkInPrompt + celebrationMessage per day.
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
  "dailyPlan": [
    {
      "dayNumber": 1,
      "theme": "Ignite",
      "checkInPrompt": "...",
      "celebrationMessage": "...",
      "tasks": [
        {
          "title": "Define success metrics",
          "type": "setup",
          "instructions": "Outline measurable success criteria.",
          "definitionOfDone": "Success criteria documented and shared.",
          "expectedMinutes": 45,
          "tags": ["strategy", "clarity"],
          "metric": { "name": "Success Criteria", "unit": "items", "target": 3 }
        },
        {
          "title": "Draft onboarding flow",
          "type": "build",
          "instructions": "Sketch the primary onboarding steps.",
          "definitionOfDone": "Wireframe of onboarding flow completed.",
          "expectedMinutes": 60,
          "tags": ["design", "prototype"],
          "metric": null
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

function buildPlanFromBlueprint(blueprint, { fallbackPurpose = null } = {}) {
  const phases = (blueprint.phases ?? []).map((phase, index) => ({
    id: randomUUID(),
    index,
    name: phase.name,
    objective: phase.objective,
    milestones: (phase.milestones ?? []).map((milestone) => ({
      id: randomUUID(),
      title: milestone.title,
      detail: milestone.detail,
      progress: 0,
      targetDay: milestone.targetDay
    })),
    keyPrinciples: phase.keyPrinciples ?? [],
    risks: (phase.risks ?? []).map((risk) => ({
      id: randomUUID(),
      risk: risk.risk,
      likelihood: risk.likelihood,
      mitigation: risk.mitigation
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

  const normalizeLikelihood = (value) => {
    const lower = typeof value === 'string' ? value.toLowerCase() : '';
    return ['low', 'medium', 'high'].includes(lower) ? lower : 'medium';
  };

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

  const days = (blueprint.dailyPlan ?? []).map((day) => ({
    id: randomUUID(),
    dayNumber: day.dayNumber,
    theme: day.theme,
    checkInPrompt: day.checkInPrompt,
    celebrationMessage: day.celebrationMessage,
    tasks: (day.tasks ?? []).map((task) => ({
      id: randomUUID(),
      title: task.title,
      type: task.type,
      expectedMinutes: task.expectedMinutes,
      instructions: task.instructions,
      definitionOfDone: task.definitionOfDone,
      metric: task.metric ?? null,
      tags: task.tags,
      isComplete: false
    }))
  }));

  const weeklyReviews = (blueprint.weeklyReviews ?? []).map((review) => ({
    id: randomUUID(),
    weekNumber: review.weekNumber,
    evidenceToCollect: review.evidenceToCollect,
    reflectionQuestions: review.reflectionQuestions,
    adaptationRules: (review.adaptationRules ?? []).map((rule) => ({
      id: randomUUID(),
      condition: rule.condition,
      response: rule.response
    }))
  }));

  return {
    id: randomUUID(),
    title: blueprint.title,
    domain: blueprint.domain,
    primaryGoal: blueprint.primaryGoal,
    createdAt: new Date().toISOString(),
    summary: blueprint.summary ?? null,
    targetOutcome: blueprint.targetOutcome,
    assumptions: blueprint.assumptions,
    constraints: blueprint.constraints,
    resources: blueprint.resources,
    purpose: planPurpose,
    keyPrinciples: planPrinciples,
    riskHighlights: planRisks,
    phases,
    days,
    weeklyReviews,
    reminderRule: {
      timeOfDay: {
        hour: blueprint.reminder.hour,
        minute: blueprint.reminder.minute
      },
      message: blueprint.reminder.message
    },
    celebrationRule: blueprint.celebrationRule,
    streakRule: blueprint.streakRule,
    callToAction: blueprint.callToAction,
    accentPalette: {
      stops: blueprint.accentPalette.map((hex) => ({ hex, opacity: 1 }))
    },
    cardPalette: {
      stops: (blueprint.cardPalette ?? blueprint.accentPalette).map((hex) => ({ hex, opacity: 1 }))
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
    const { error } = await supabase
      .from('ai_generation_jobs')
      .update({
        status: 'completed',
        result: plan,
        response_id: responseId ?? null,
        error: null
      })
      .eq('id', job.id);

    if (error) {
      console.error('Failed to mark job completed', error);
    } else {
      console.log('Job completed', { id: job.id, model: job.model ?? openAIModel });
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
