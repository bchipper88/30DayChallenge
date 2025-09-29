import OpenAI from "https://deno.land/x/openai@v4.53.2/mod.ts";

const openai = new OpenAI({
  apiKey: Deno.env.get("OPENAI_API_KEY")!,
  timeout: 30000
});

const challengePlanSchema = {
  type: "object",
  additionalProperties: false,
  required: ["plan"],
  properties: {
    plan: {
      type: "object",
      additionalProperties: false,
      required: [
        "id",
        "title",
        "domain",
        "primaryGoal",
        "targetOutcome",
        "assumptions",
        "constraints",
        "resources",
        "phases",
        "days",
        "weeklyReviews",
        "reminderRule",
        "celebrationRule",
        "streakRule",
        "callToAction",
        "accentPalette"
      ],
      properties: {
        id: { type: "string", format: "uuid" },
        title: { type: "string" },
        domain: {
          type: "string",
          enum: [
            "fitness",
            "business",
            "learning",
            "creative",
            "productivity",
            "finance",
            "wellbeing",
            "other"
          ]
        },
        primaryGoal: { type: "string" },
        targetOutcome: {
          type: "object",
          additionalProperties: false,
          required: ["metric", "value", "unit", "timeframe"],
          properties: {
            metric: { type: "string" },
            value: { type: "number" },
            unit: { type: "string" },
            timeframe: { type: "string" }
          }
        },
        assumptions: { type: "array", items: { type: "string" } },
        constraints: { type: "array", items: { type: "string" } },
        resources: { type: "array", items: { type: "string" } },
        phases: {
          type: "array",
          minItems: 4,
          items: {
            type: "object",
            additionalProperties: false,
            required: [
              "id",
              "index",
              "name",
              "objective",
              "milestones",
              "keyPrinciples",
              "risks"
            ],
            properties: {
              id: { type: "string", format: "uuid" },
              index: { type: "integer", minimum: 0, maximum: 3 },
              name: { type: "string" },
              objective: { type: "string" },
              milestones: {
                type: "array",
                minItems: 1,
                items: {
                  type: "object",
                  additionalProperties: false,
                  required: ["id", "title", "detail", "progress", "targetDay"],
                  properties: {
                    id: { type: "string", format: "uuid" },
                    title: { type: "string" },
                    detail: { type: "string" },
                    progress: { type: "number", minimum: 0, maximum: 1 },
                    targetDay: { type: "integer", minimum: 1, maximum: 30 }
                  }
                }
              },
              keyPrinciples: { type: "array", items: { type: "string" } },
              risks: {
                type: "array",
                items: {
                  type: "object",
                  additionalProperties: false,
                  required: ["id", "risk", "likelihood", "mitigation"],
                  properties: {
                    id: { type: "string", format: "uuid" },
                    risk: { type: "string" },
                    likelihood: {
                      type: "string",
                      enum: ["low", "medium", "high"]
                    },
                    mitigation: { type: "string" }
                  }
                }
              }
            }
          }
        },
        days: {
          type: "array",
          minItems: 30,
          maxItems: 30,
          items: {
            type: "object",
            additionalProperties: false,
            required: [
              "id",
              "dayNumber",
              "theme",
              "tasks",
              "checkInPrompt",
              "celebrationMessage"
            ],
            properties: {
              id: { type: "string", format: "uuid" },
              dayNumber: { type: "integer", minimum: 1, maximum: 30 },
              theme: { type: "string" },
              checkInPrompt: { type: "string" },
              celebrationMessage: { type: "string" },
              tasks: {
                type: "array",
                minItems: 2,
                items: {
                  type: "object",
                  additionalProperties: false,
                  required: [
                    "id",
                    "title",
                    "type",
                    "expectedMinutes",
                    "instructions",
                    "definitionOfDone",
                    "tags",
                    "isComplete"
                  ],
                  properties: {
                    id: { type: "string", format: "uuid" },
                    title: { type: "string" },
                    type: {
                      type: "string",
                      enum: [
                        "setup",
                        "research",
                        "practice",
                        "review",
                        "reflection",
                        "outreach",
                        "build",
                        "ship"
                      ]
                    },
                    expectedMinutes: { type: "integer", minimum: 10, maximum: 120 },
                    instructions: { type: "string" },
                    definitionOfDone: { type: "string" },
                    metric: {
                      anyOf: [
                        {
                          type: "object",
                          additionalProperties: false,
                          required: ["name", "unit", "target"],
                          properties: {
                            name: { type: "string" },
                            unit: { type: "string" },
                            target: { type: "number" }
                          }
                        },
                        { type: "null" }
                      ]
                    },
                    tags: { type: "array", items: { type: "string" } },
                    isComplete: { type: "boolean" }
                  }
                }
              }
            }
          }
        },
        weeklyReviews: {
          type: "array",
          minItems: 4,
          maxItems: 4,
          items: {
            type: "object",
            additionalProperties: false,
            required: [
              "id",
              "weekNumber",
              "evidenceToCollect",
              "reflectionQuestions",
              "adaptationRules"
            ],
            properties: {
              id: { type: "string", format: "uuid" },
              weekNumber: { type: "integer", minimum: 1, maximum: 4 },
              evidenceToCollect: { type: "array", items: { type: "string" } },
              reflectionQuestions: { type: "array", items: { type: "string" } },
              adaptationRules: {
                type: "array",
                items: {
                  type: "object",
                  additionalProperties: false,
                  required: ["id", "condition", "response"],
                  properties: {
                    id: { type: "string", format: "uuid" },
                    condition: { type: "string" },
                    response: { type: "string" }
                  }
                }
              }
            }
          }
        },
        reminderRule: {
          type: "object",
          additionalProperties: false,
          required: ["timeOfDay", "message"],
          properties: {
            timeOfDay: {
              type: "object",
              additionalProperties: false,
              required: ["hour", "minute"],
              properties: {
                hour: { type: "integer", minimum: 0, maximum: 23 },
                minute: { type: "integer", minimum: 0, maximum: 59 }
              }
            },
            message: { type: "string" }
          }
        },
        celebrationRule: {
          type: "object",
          additionalProperties: false,
          required: ["trigger", "message"],
          properties: {
            trigger: { type: "string", enum: ["dayComplete", "milestoneComplete"] },
            message: { type: "string" }
          }
        },
        streakRule: {
          type: "object",
          additionalProperties: false,
          required: ["thresholdMinutes", "graceDays"],
          properties: {
            thresholdMinutes: { type: "integer", minimum: 10, maximum: 180 },
            graceDays: { type: "integer", minimum: 0, maximum: 5 }
          }
        },
        callToAction: { type: "string" },
        accentPalette: {
          type: "object",
          additionalProperties: false,
          required: ["stops"],
          properties: {
            stops: {
              type: "array",
              minItems: 3,
              items: {
                type: "object",
                additionalProperties: false,
                required: ["hex", "opacity"],
                properties: {
                  hex: { type: "string", pattern: "^#?[0-9A-Fa-f]{6}$" },
                  opacity: { type: "number", minimum: 0, maximum: 1 }
                }
              }
            }
          }
        }
      }
    }
  }
};

const blueprintSchema = {
  type: "object",
  additionalProperties: false,
  required: [
    "title",
    "domain",
    "primaryGoal",
    "targetOutcome",
    "assumptions",
    "constraints",
    "resources",
    "callToAction",
    "reminder",
    "celebrationRule",
    "streakRule",
    "accentPalette",
    "phases",
    "dailyPlan",
    "weeklyReviews"
  ],
  properties: {
    title: { type: "string" },
    domain: {
      type: "string",
      enum: [
        "fitness",
        "business",
        "learning",
        "creative",
        "productivity",
        "finance",
        "wellbeing",
        "other"
      ]
    },
    primaryGoal: { type: "string" },
    targetOutcome: {
      type: "object",
      additionalProperties: false,
      required: ["metric", "value", "unit", "timeframe"],
      properties: {
        metric: { type: "string" },
        value: { type: "number" },
        unit: { type: "string" },
        timeframe: { type: "string" }
      }
    },
    assumptions: {
      type: "array",
      minItems: 2,
      items: { type: "string" }
    },
    constraints: {
      type: "array",
      minItems: 2,
      items: { type: "string" }
    },
    resources: {
      type: "array",
      minItems: 2,
      items: { type: "string" }
    },
    callToAction: { type: "string" },
    reminder: {
      type: "object",
      additionalProperties: false,
      required: ["hour", "minute", "message"],
      properties: {
        hour: { type: "integer", minimum: 0, maximum: 23 },
        minute: { type: "integer", minimum: 0, maximum: 59 },
        message: { type: "string" }
      }
    },
    celebrationRule: {
      type: "object",
      additionalProperties: false,
      required: ["trigger", "message"],
      properties: {
        trigger: { type: "string", enum: ["dayComplete", "milestoneComplete"] },
        message: { type: "string" }
      }
    },
    streakRule: {
      type: "object",
      additionalProperties: false,
      required: ["thresholdMinutes", "graceDays"],
      properties: {
        thresholdMinutes: { type: "integer", minimum: 10, maximum: 180 },
        graceDays: { type: "integer", minimum: 0, maximum: 5 }
      }
    },
    accentPalette: {
      type: "array",
      minItems: 3,
      maxItems: 4,
      items: { type: "string", pattern: "^#?[0-9A-Fa-f]{6}$" }
    },
    phases: {
      type: "array",
      minItems: 4,
      maxItems: 4,
      items: {
        type: "object",
        additionalProperties: false,
        required: [
          "name",
          "objective",
          "milestones",
          "keyPrinciples",
          "risks"
        ],
        properties: {
          name: { type: "string" },
          objective: { type: "string" },
          milestones: {
            type: "array",
            minItems: 1,
            items: {
              type: "object",
              additionalProperties: false,
              required: ["title", "detail", "targetDay"],
              properties: {
                title: { type: "string" },
                detail: { type: "string" },
                targetDay: { type: "integer", minimum: 1, maximum: 30 }
              }
            }
          },
          keyPrinciples: {
            type: "array",
            minItems: 3,
            items: { type: "string" }
          },
          risks: {
            type: "array",
            minItems: 2,
            items: {
              type: "object",
              additionalProperties: false,
              required: ["risk", "likelihood", "mitigation"],
              properties: {
                risk: { type: "string" },
                likelihood: {
                  type: "string",
                  enum: ["low", "medium", "high"]
                },
                mitigation: { type: "string" }
              }
            }
          }
        }
      }
    },
    dailyPlan: {
      type: "array",
      minItems: 30,
      maxItems: 30,
      items: {
        type: "object",
        additionalProperties: false,
        required: [
          "dayNumber",
          "theme",
          "checkInPrompt",
          "celebrationMessage",
          "tasks"
        ],
        properties: {
          dayNumber: { type: "integer", minimum: 1, maximum: 30 },
          theme: { type: "string" },
          checkInPrompt: { type: "string" },
          celebrationMessage: { type: "string" },
          tasks: {
            type: "array",
            minItems: 2,
            items: {
              type: "object",
              additionalProperties: false,
              required: [
                "title",
                "type",
                "expectedMinutes",
                "instructions",
                "definitionOfDone",
                "tags",
                "metric"
              ],
              properties: {
                title: { type: "string" },
                type: {
                  type: "string",
                  enum: [
                    "setup",
                    "research",
                    "practice",
                    "review",
                    "reflection",
                    "outreach",
                    "build",
                    "ship"
                  ]
                },
                expectedMinutes: { type: "integer", minimum: 10, maximum: 180 },
                instructions: { type: "string" },
                definitionOfDone: { type: "string" },
                tags: {
                  type: "array",
                  minItems: 2,
                  items: { type: "string" }
                },
                metric: {
                  anyOf: [
                    {
                      type: "object",
                      additionalProperties: false,
                      required: ["name", "unit", "target"],
                      properties: {
                        name: { type: "string" },
                        unit: { type: "string" },
                        target: { type: "number" }
                      }
                    },
                    { type: "null" }
                  ]
                }
              }
            }
          }
        }
      }
    },
    weeklyReviews: {
      type: "array",
      minItems: 4,
      maxItems: 4,
      items: {
        type: "object",
        additionalProperties: false,
        required: [
          "weekNumber",
          "evidenceToCollect",
          "reflectionQuestions",
          "adaptationRules"
        ],
        properties: {
          weekNumber: { type: "integer", minimum: 1, maximum: 4 },
          evidenceToCollect: {
            type: "array",
            minItems: 3,
            items: { type: "string" }
          },
          reflectionQuestions: {
            type: "array",
            minItems: 3,
            items: { type: "string" }
          },
          adaptationRules: {
            type: "array",
            minItems: 3,
            items: {
              type: "object",
              additionalProperties: false,
              required: ["condition", "response"],
              properties: {
                condition: { type: "string" },
                response: { type: "string" }
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
• Outline exactly 4 phases (7-8 day spans) with objectives, 2-3 milestones, 3 principles, and 2-3 risks (likelihood low/medium/high) each.
• Provide a "dailyPlan" array with exactly 30 entries (dayNumber 1..30) and each day containing 2-3 tasks. Tasks require: title, type (setup/research/practice/review/reflection/outreach/build/ship), expectedMinutes, instructions (imperative), definitionOfDone, tags (2-3), and metric {name, unit, target} (set metric to null when not applicable). Add motivating checkInPrompt + celebrationMessage per day.
• Provide four weekly reviews (weekNumber 1..4) each with 3 evidence items, 3 reflection questions, and 3 adaptation rules (condition + response).
• Include assumptions, constraints, resources, callToAction, reminder (hour/minute/message), celebrationRule (trigger/message), streakRule (thresholdMinutes/graceDays), and accentPalette (3-4 hex colors).
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
  "callToAction": "...",
  "reminder": { "hour": 8, "minute": 30, "message": "..." },
  "celebrationRule": { "trigger": "dayComplete", "message": "..." },
  "streakRule": { "thresholdMinutes": 45, "graceDays": 2 },
  "accentPalette": ["#FF7EB3", "#A855F7", "#3B82F6"],
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

type Payload = { prompt: string };

interface Blueprint {
  title: string;
  domain: string;
  primaryGoal: string;
  targetOutcome: { metric: string; value: number; unit: string; timeframe: string };
  assumptions: string[];
  constraints: string[];
  resources: string[];
  callToAction: string;
  reminder: { hour: number; minute: number; message: string };
  celebrationRule: { trigger: "dayComplete" | "milestoneComplete"; message: string };
  streakRule: { thresholdMinutes: number; graceDays: number };
  accentPalette: string[];
  phases: Array<{
    name: string;
    objective: string;
    milestones: Array<{ title: string; detail: string; targetDay: number }>;
    keyPrinciples: string[];
    risks: Array<{ risk: string; likelihood: "low" | "medium" | "high"; mitigation: string }>;
  }>;
  dailyPlan: Array<{
    dayNumber: number;
    theme: string;
    checkInPrompt: string;
    celebrationMessage: string;
    tasks: Array<{
      title: string;
      type: string;
      instructions: string;
      definitionOfDone: string;
      expectedMinutes: number;
      tags: string[];
      metric?: { name: string; unit: string; target: number } | null;
    }>;
  }>;
  weeklyReviews: Array<{
    weekNumber: number;
    evidenceToCollect: string[];
    reflectionQuestions: string[];
    adaptationRules: Array<{ condition: string; response: string }>;
  }>;
}

type ResponseBody = { plan: ChallengePlan };
type ChallengePlan = typeof challengePlanSchema.properties.plan;

function buildPlanFromBlueprint(blueprint: Blueprint): ResponseBody {
  if (blueprint.dailyPlan.length !== 30) {
    throw new Error(`dailyPlan must contain 30 entries, received ${blueprint.dailyPlan.length}`);
  }
  if (blueprint.phases.length !== 4) {
    throw new Error(`phases must contain 4 entries, received ${blueprint.phases.length}`);
  }

  const domain = blueprint.domain as ChallengePlan["domain"];

  const phases = blueprint.phases.map((phase, index) => ({
    id: crypto.randomUUID(),
    index,
    name: phase.name,
    objective: phase.objective,
    milestones: phase.milestones.map((milestone) => ({
      id: crypto.randomUUID(),
      title: milestone.title,
      detail: milestone.detail,
      progress: 0,
      targetDay: milestone.targetDay
    })),
    keyPrinciples: phase.keyPrinciples,
    risks: phase.risks.map((risk) => ({
      id: crypto.randomUUID(),
      risk: risk.risk,
      likelihood: risk.likelihood,
      mitigation: risk.mitigation
    }))
  }));

  const days = blueprint.dailyPlan.map((day) => ({
    id: crypto.randomUUID(),
    dayNumber: day.dayNumber,
    theme: day.theme,
    checkInPrompt: day.checkInPrompt,
    celebrationMessage: day.celebrationMessage,
    tasks: day.tasks.map((task) => ({
      id: crypto.randomUUID(),
      title: task.title,
      type: task.type as ChallengePlan["days"][number]["tasks"][number]["type"],
      expectedMinutes: task.expectedMinutes,
      instructions: task.instructions,
      definitionOfDone: task.definitionOfDone,
      metric: task.metric ?? null,
      tags: task.tags,
      isComplete: false
    }))
  }));

  const weeklyReviews = blueprint.weeklyReviews.map((review) => ({
    id: crypto.randomUUID(),
    weekNumber: review.weekNumber,
    evidenceToCollect: review.evidenceToCollect,
    reflectionQuestions: review.reflectionQuestions,
    adaptationRules: review.adaptationRules.map((rule) => ({
      id: crypto.randomUUID(),
      condition: rule.condition,
      response: rule.response
    }))
  }));

  const plan: ChallengePlan = {
    id: crypto.randomUUID(),
    title: blueprint.title,
    domain,
    primaryGoal: blueprint.primaryGoal,
    targetOutcome: blueprint.targetOutcome,
    assumptions: blueprint.assumptions,
    constraints: blueprint.constraints,
    resources: blueprint.resources,
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
    }
  };

  return { plan };
}

Deno.serve(async (req: Request): Promise<Response> => {
  try {
    const { prompt } = (await req.json()) as Payload;

    console.log("Invoking OpenAI", { promptLength: prompt.length });
    const completion = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      temperature: 0.6,
      response_format: {
        type: "json_schema",
        json_schema: {
          name: "ChallengePlanBlueprint",
          schema: blueprintSchema,
          strict: true
        }
      },
      messages: [
        { role: "system", content: blueprintPrompt },
        { role: "user", content: prompt }
      ]
    });

    console.log("OpenAI responded", {
      finishReason: completion.choices[0]?.finish_reason,
      usage: completion.usage
    });

    const message = completion.choices[0]?.message;
    if (!message) {
      throw new Error("Assistant returned no message content");
    }

    const content = message.content;

    const parseJson = (value: string): Blueprint => {
      try {
        return JSON.parse(value) as Blueprint;
      } catch (parseError) {
        console.error("Blueprint JSON parse failed", parseError, {
          snippet: value.slice(0, 200)
        });
        throw new Error("Assistant returned invalid JSON");
      }
    };

    let blueprintData: Blueprint | null = null;

    if (Array.isArray(content)) {
      for (const part of content) {
        if (part && typeof part === "object") {
          if ("json" in part && part.json) {
            const raw = part.json as unknown;
            if (typeof raw === "string") {
              blueprintData = parseJson(raw);
            } else {
              blueprintData = raw as Blueprint;
            }
            break;
          }

          if ("text" in part && typeof (part as { text?: unknown }).text === "string") {
            const text = ((part as { text?: string }).text ?? "").trim();
            if (text.length > 0) {
              blueprintData = parseJson(text);
              break;
            }
          }
        } else if (typeof part === "string" && part.trim().length > 0) {
          blueprintData = parseJson(part);
          break;
        }
      }
    } else if (typeof content === "string" && content.trim().length > 0) {
      blueprintData = parseJson(content);
    }

    if (!blueprintData) {
      throw new Error("Assistant returned empty content");
    }

    const blueprint = blueprintData;
    console.log("Blueprint summary", {
      phases: blueprint.phases?.length,
      days: blueprint.dailyPlan?.length,
      weeklyReviews: blueprint.weeklyReviews?.length
    });
    const payload = buildPlanFromBlueprint(blueprint);
    console.log("Plan generated", {
      phases: payload.plan.phases.length,
      days: payload.plan.days.length
    });

    return new Response(JSON.stringify(payload), {
      headers: { "Content-Type": "application/json" }
    });
  } catch (error) {
    console.error("AI plan generation failed", error);
    const message = error instanceof Error ? error.message : "Unknown error";
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
