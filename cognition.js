(function attachNornCognition(root) {
  "use strict";

  const VERSION = 1;
  const EPISODE_LIMIT = 512;
  const RECURRENT_UNITS = 128;
  const RECURRENT_DEGREE = 4;
  const CHEMICAL_NAMES = Object.freeze([
    "glucose", "hunger", "curiosity", "fatigue", "reward",
    "punishment", "stress", "socialComfort", "arousal", "satiety"
  ]);
  const ACTION_IDS = Object.freeze(["fruit", "spinner", "rest", "observe_peer", "idle"]);
  const CONTEXT_IDS = Object.freeze(["hungry", "curious", "fatigued", "social", "settled"]);
  const INPUT_NAMES = Object.freeze([
    ...CHEMICAL_NAMES,
    "nearFruit", "nearSpinner", "peerNearby", "guidance",
    "fruitAffordance", "spinnerAffordance", "fruitLanguageSignal", "spinnerLanguageSignal",
    "praiseSignal", "scoldSignal"
  ]);

  // Rates are concentration points per simulated second. Stimulus rates are
  // multiplied by a bounded [0, 1] value supplied by the host adapter.
  const REACTION_TABLE = Object.freeze([
    { id: "metabolism", target: "hunger", rate: 1.55 },
    { id: "curiosity", target: "curiosity", rate: 0.68, trait: "curiosity", traitRate: 0.34 },
    { id: "glucose-use", target: "glucose", rate: -0.55 },
    { id: "active-fatigue", target: "fatigue", rate: 0.12, stimulus: "active" },
    { id: "rest-recovery", target: "fatigue", rate: -0.36, stimulus: "resting" },
    { id: "reward-decay", target: "reward", rate: -7 },
    { id: "punishment-decay", target: "punishment", rate: -7 },
    { id: "stress-decay", target: "stress", rate: -1.6 },
    { id: "social-comfort-decay", target: "socialComfort", rate: -0.15 },
    { id: "peer-comfort", target: "socialComfort", rate: 0.55, stimulus: "nearbyPeer" },
    { id: "arousal-decay", target: "arousal", rate: -0.6 },
    { id: "satiety-decay", target: "satiety", rate: -0.8 }
  ]);
  const CHEMICAL_COUPLINGS = Object.freeze([
    { source: "stress", target: "arousal", rate: 0.12 },
    { source: "reward", target: "stress", rate: -0.08 },
    { source: "punishment", target: "stress", rate: 0.1 },
    { source: "satiety", target: "hunger", rate: -0.03 },
    { source: "hunger", target: "stress", rate: 0.025 }
  ]);

  const clamp = (value, low, high) => Math.max(low, Math.min(high, value));
  const finiteOr = (value, fallback) => Number.isFinite(value) ? value : fallback;
  const normalized = value => clamp(finiteOr(value, 0), 0, 100) / 100;
  const copyChemistry = chemistry => Object.fromEntries(CHEMICAL_NAMES.map(name => [name, chemistry[name]]));

  function makeRandom(seed) {
    let value = seed >>> 0;
    if (value === 0) value = 0x6d2b79f5;
    return () => {
      value = (Math.imul(value, 1664525) + 1013904223) >>> 0;
      return value / 4294967296;
    };
  }

  function normalizeAssociations(source) {
    return Object.fromEntries(ACTION_IDS.map(actionId => [
      actionId,
      clamp(finiteOr(source && source[actionId], 0), 0, 1)
    ]));
  }

  function makeContextMap(value = 0.5) {
    return Object.fromEntries(ACTION_IDS.map(actionId => [
      actionId,
      Object.fromEntries(CONTEXT_IDS.map(contextId => [contextId, value]))
    ]));
  }

  function getContextIds(chemistry, peerCount) {
    const contexts = [];
    if (chemistry.hunger >= 35) contexts.push("hungry");
    if (chemistry.curiosity >= 40) contexts.push("curious");
    if (chemistry.fatigue >= 40) contexts.push("fatigued");
    if (peerCount > 0) contexts.push("social");
    return contexts.length ? contexts : ["settled"];
  }

  function normalizeContextMap(source, fallback = 0.5) {
    const result = makeContextMap(fallback);
    for (const actionId of ACTION_IDS) {
      for (const contextId of CONTEXT_IDS) {
        result[actionId][contextId] = clamp(finiteOr(
          source && source[actionId] && source[actionId][contextId],
          fallback
        ), 0, 1);
      }
    }
    return result;
  }

  function makePolicy(seed) {
    const random = makeRandom((seed ^ 0x9e3779b9) >>> 0);
    const inputWeights = new Float32Array(RECURRENT_UNITS * INPUT_NAMES.length);
    const recurrentIndices = new Uint16Array(RECURRENT_UNITS * RECURRENT_DEGREE);
    const recurrentWeights = new Float32Array(RECURRENT_UNITS * RECURRENT_DEGREE);
    const actionWeights = new Float32Array(ACTION_IDS.length * RECURRENT_UNITS);
    for (let index = 0; index < inputWeights.length; index += 1) {
      inputWeights[index] = (random() * 2 - 1) * 0.12;
    }
    for (let unit = 0; unit < RECURRENT_UNITS; unit += 1) {
      for (let edge = 0; edge < RECURRENT_DEGREE; edge += 1) {
        const offset = unit * RECURRENT_DEGREE + edge;
        recurrentIndices[offset] = Math.floor(random() * RECURRENT_UNITS);
        recurrentWeights[offset] = (random() * 2 - 1) * 0.16;
      }
    }
    for (let index = 0; index < actionWeights.length; index += 1) {
      actionWeights[index] = (random() * 2 - 1) * 0.055;
    }
    return { inputWeights, recurrentIndices, recurrentWeights, actionWeights };
  }

  function createState(seed, traits = {}, initial = {}) {
    const stableSeed = (finiteOr(seed, 1) >>> 0) || 1;
    const hunger = clamp(finiteOr(initial.hunger, 45), 0, 100);
    const curiosity = clamp(finiteOr(initial.curiosity, 45), 0, 100);
    const chemistry = {
      glucose: 100 - hunger,
      hunger,
      curiosity,
      fatigue: clamp(finiteOr(initial.fatigue, 15), 0, 100),
      reward: 0,
      punishment: 0,
      stress: 0,
      socialComfort: 50,
      arousal: curiosity * 0.35,
      satiety: clamp(100 - hunger, 0, 100)
    };
    return {
      version: VERSION,
      seed: stableSeed,
      traits: {
        curiosity: clamp(finiteOr(traits.curiosity, 0.5), 0, 1),
        sociability: clamp(finiteOr(traits.sociability, 0.5), 0, 1)
      },
      chemistry,
      actionAssociations: normalizeAssociations(initial.actionAssociations || initial.learned),
      contextAssociations: normalizeContextMap(initial.contextAssociations),
      episodes: [],
      nextEpisodeId: 1,
      eligibility: Object.fromEntries(ACTION_IDS.map(actionId => [actionId, 0])),
      contextEligibility: makeContextMap(0),
      hidden: new Float32Array(RECURRENT_UNITS),
      decisionCount: 0,
      commitmentUntil: 0,
      lastDecision: null,
      policy: makePolicy(stableSeed)
    };
  }

  function advanceChemistry(state, stimuli = {}, dt = 0.1) {
    if (!state || !state.chemistry || !Number.isFinite(dt) || dt <= 0) return null;
    const seconds = clamp(dt, 0, 0.5);
    const boundedStimuli = {
      active: clamp(finiteOr(stimuli.active, 0), 0, 1),
      resting: clamp(finiteOr(stimuli.resting, 0), 0, 1),
      nearbyPeer: clamp(finiteOr(stimuli.nearbyPeer, 0), 0, 1),
      stress: clamp(finiteOr(stimuli.stress, 0), -1, 1)
    };
    const deltas = Object.fromEntries(CHEMICAL_NAMES.map(name => [name, 0]));

    for (const reaction of REACTION_TABLE) {
      let rate = reaction.rate;
      if (reaction.trait) rate += state.traits[reaction.trait] * reaction.traitRate;
      if (reaction.stimulus) rate *= boundedStimuli[reaction.stimulus];
      deltas[reaction.target] += rate * seconds;
    }
    deltas.stress += boundedStimuli.stress * seconds;
    for (const coupling of CHEMICAL_COUPLINGS) {
      deltas[coupling.target] += state.chemistry[coupling.source] / 100 * coupling.rate * seconds;
    }

    for (const name of CHEMICAL_NAMES) {
      state.chemistry[name] = clamp(state.chemistry[name] + deltas[name], 0, 100);
    }
    return copyChemistry(state.chemistry);
  }

  function getInputVector(state, observation = {}) {
    const chemistry = observation.chemistry || state.chemistry;
    const input = CHEMICAL_NAMES.map(name => normalized(chemistry[name]));
    const objects = Array.isArray(observation.nearbyObjects) ? observation.nearbyObjects : [];
    const findObject = id => objects.find(item => item && item.id === id);
    const fruit = findObject("fruit");
    const spinner = findObject("spinner");
    const distanceSignal = item => item
      ? clamp(1 - Math.max(0, finiteOr(item.distance, 0)) / 900, 0, 1)
      : 0;
    const peers = Array.isArray(observation.nearbyNorns) ? observation.nearbyNorns : [];
    const guidance = observation.guidance;
    const languages = observation.languageSignals || {};
    input.push(
      distanceSignal(fruit),
      distanceSignal(spinner),
      peers.length > 0 ? 1 : 0,
      guidance && (guidance.objectId === "fruit" || guidance.objectId === "spinner") ? 1 : 0,
      fruit && fruit.affordances && fruit.affordances.includes("eat") ? 1 : 0,
      spinner && spinner.affordances && spinner.affordances.includes("play") ? 1 : 0,
      languages.targetId === "fruit" ? 1 : 0,
      languages.targetId === "spinner" ? 1 : 0,
      languages.praise ? 1 : 0,
      languages.scold ? 1 : 0
    );
    return input;
  }

  function updateRecurrentState(state, observation) {
    const { inputWeights, recurrentIndices, recurrentWeights } = state.policy;
    const input = getInputVector(state, observation);
    const previous = state.hidden;
    const next = new Float32Array(RECURRENT_UNITS);
    for (let unit = 0; unit < RECURRENT_UNITS; unit += 1) {
      let activation = 0;
      const inputOffset = unit * INPUT_NAMES.length;
      for (let index = 0; index < INPUT_NAMES.length; index += 1) {
        activation += inputWeights[inputOffset + index] * input[index];
      }
      const edgeOffset = unit * RECURRENT_DEGREE;
      for (let edge = 0; edge < RECURRENT_DEGREE; edge += 1) {
        const weightIndex = edgeOffset + edge;
        activation += recurrentWeights[weightIndex] * previous[recurrentIndices[weightIndex]];
      }
      next[unit] = Math.tanh(activation * 1.4);
    }
    state.hidden = next;
    state.decisionCount += 1;
  }

  function policySignals(state) {
    const output = {};
    for (let actionIndex = 0; actionIndex < ACTION_IDS.length; actionIndex += 1) {
      let value = 0;
      const offset = actionIndex * RECURRENT_UNITS;
      for (let unit = 0; unit < RECURRENT_UNITS; unit += 1) {
        value += state.policy.actionWeights[offset + unit] * state.hidden[unit];
      }
      output[ACTION_IDS[actionIndex]] = clamp(value * 3, -2.5, 2.5);
    }
    return output;
  }

  function retrieveEpisodes(state, observation = {}, limit = 3) {
    const now = Math.max(0, finiteOr(observation.time, 0));
    const chemistry = observation.chemistry || state.chemistry;
    const targetId = observation.targetId || observation.guidance && observation.guidance.objectId || null;
    const peersNearby = Array.isArray(observation.nearbyNorns) && observation.nearbyNorns.length > 0;
    return state.episodes.map(episode => {
      const age = Math.max(0, now - episode.time);
      const recency = 1 / (1 + age / 45);
      const targetMatch = targetId && episode.targetId === targetId ? 1 : 0;
      const peerMatch = peersNearby && ["observe", "observe-feedback", "hear"].includes(episode.eventType) ? 1 : 0;
      const driveMatch = 1 - (
        Math.abs(episode.observation.hunger - chemistry.hunger)
        + Math.abs(episode.observation.curiosity - chemistry.curiosity)
      ) / 200;
      const context = Math.max(targetMatch, peerMatch, driveMatch * 0.5);
      const score = episode.salience * 0.52 + recency * 0.28 + context * 0.2;
      return { episode, score };
    })
      .sort((a, b) => b.score - a.score || b.episode.id - a.episode.id)
      .slice(0, clamp(Math.floor(limit), 0, 3))
      .map(item => item.episode);
  }

  function episodicActionBias(episodes, actionId) {
    let bias = 0;
    for (const episode of episodes) {
      if (episode.actionId !== actionId || episode.valence === 0) continue;
      bias += episode.valence * episode.salience * 2.4;
    }
    return clamp(bias, -4, 4);
  }

  function contextualActionBias(state, actionId, contexts) {
    const total = contexts.reduce((sum, contextId) =>
      sum + (state.contextAssociations[actionId][contextId] - 0.5) * 12, 0);
    return contexts.length ? total / contexts.length : 0;
  }

  function scoreDecision(state, observation = {}) {
    const chemistry = observation.chemistry || state.chemistry;
    const associations = state.actionAssociations;
    const policy = policySignals(state);
    const recalled = retrieveEpisodes(state, observation);
    const fruitNeed = Math.max(0, chemistry.hunger - 17) * 1.05;
    const spinnerNeed = Math.max(0, chemistry.curiosity - 16)
      * (0.58 + state.traits.curiosity * 0.46);
    const fruitHabit = associations.fruit * 35;
    const spinnerHabit = associations.spinner * 32;
    const fruitMemory = episodicActionBias(recalled, "fruit");
    const spinnerMemory = episodicActionBias(recalled, "spinner");
    const nearbyNorns = Array.isArray(observation.nearbyNorns) ? observation.nearbyNorns : [];
    const contexts = getContextIds(chemistry, nearbyNorns.length);
    const fruitContext = clamp(policy.fruit + fruitMemory + contextualActionBias(state, "fruit", contexts), -8, 8);
    const spinnerContext = clamp(policy.spinner + spinnerMemory + contextualActionBias(state, "spinner", contexts), -8, 8);
    const fruitScore = fruitNeed + fruitHabit + fruitContext;
    const spinnerScore = spinnerNeed + spinnerHabit + spinnerContext;
    const restNeed = chemistry.fatigue * 0.3 + Math.max(0, 28 - chemistry.glucose) * 0.2;
    const observeNeed = nearbyNorns.length > 0
      ? 8 + Math.max(0, 50 - chemistry.socialComfort) * 0.12
      : 0;
    const actionScores = {
      fruit: fruitScore,
      spinner: spinnerScore,
      rest: restNeed + associations.rest * 20 + contextualActionBias(state, "rest", contexts) + policy.rest,
      observe_peer: observeNeed + associations.observe_peer * 20
        + contextualActionBias(state, "observe_peer", contexts) + policy.observe_peer,
      idle: 14 + associations.idle * 20 + contextualActionBias(state, "idle", contexts) + policy.idle
    };

    let actionId;
    if (fruitScore >= 11 || spinnerScore >= 14) {
      actionId = fruitScore > spinnerScore ? "fruit" : "spinner";
    } else if (actionScores.rest > 18) {
      actionId = "rest";
    } else if (actionScores.observe_peer > actionScores.idle && observeNeed > 0) {
      actionId = "observe_peer";
    } else {
      actionId = "idle";
    }

    let reason;
    if (actionId === "fruit") {
      reason = fruitMemory > 1 || fruitHabit > 8
        ? "Remembering that fruit eased hunger before"
        : "Hunger is drawing attention to the fruit";
    } else if (actionId === "spinner") {
      reason = spinnerMemory > 1 || spinnerHabit > 8
        ? "Remembering that the spinner was enjoyable"
        : "Curiosity is pulling toward the spinner";
    } else if (actionId === "rest") {
      reason = "Fatigue or low energy is calling for a pause";
    } else if (actionId === "observe_peer") {
      reason = "Staying near another Norn to notice what they do";
    } else {
      reason = "Their immediate needs are settled";
    }

    return {
      actionId,
      actionScores,
      reason,
      recalledEpisodeIds: recalled.map(episode => episode.id),
      components: {
        fruitNeed, fruitHabit, fruitContext, fruitScore,
        spinnerNeed, spinnerHabit, spinnerContext, spinnerScore,
        restNeed, observeNeed
      }
    };
  }

  function structuredCloneDecision(decision) {
    return decision ? {
      actionId: decision.actionId,
      actionScores: { ...decision.actionScores },
      reason: decision.reason,
      recalledEpisodeIds: [...decision.recalledEpisodeIds],
      components: { ...decision.components }
    } : null;
  }

  function applyCommitment(state, decision, observation = {}, persist = false) {
    const now = Math.max(0, finiteOr(observation.time, 0));
    const previousAction = state.lastDecision && state.lastDecision.actionId;
    const previousIsTarget = previousAction === "fruit" || previousAction === "spinner";
    let commitmentUntil = state.commitmentUntil;
    if (previousIsTarget && decision.actionId !== previousAction && now < commitmentUntil) {
      const nextScore = decision.actionScores[decision.actionId];
      const previousScore = decision.actionScores[previousAction];
      if (nextScore < previousScore + 18) {
        decision.actionId = previousAction;
        decision.reason = previousAction === "fruit"
          ? "Continuing toward fruit while the current choice is still committed"
          : "Continuing toward the spinner while the current choice is still committed";
      }
    }
    const nextIsTarget = decision.actionId === "fruit" || decision.actionId === "spinner";
    if (nextIsTarget && (!previousIsTarget || decision.actionId !== previousAction)) {
      commitmentUntil = now + 1.2;
    } else if (!nextIsTarget) {
      commitmentUntil = now;
    }
    if (persist) state.commitmentUntil = commitmentUntil;
    return decision;
  }

  function decide(state, observation = {}) {
    if (!state || !state.policy) return null;
    updateRecurrentState(state, observation);
    state.lastDecision = applyCommitment(state, scoreDecision(state, observation), observation, true);
    return structuredCloneDecision(state.lastDecision);
  }

  function preview(state, observation = {}) {
    if (!state || !state.policy) return null;
    return structuredCloneDecision(applyCommitment(state, scoreDecision(state, observation), observation));
  }

  function deriveLearningDelta(eventType, explicitDelta) {
    if (Number.isFinite(explicitDelta)) return clamp(explicitDelta, -0.2, 0.2);
    if (eventType === "food") return 0.12;
    if (eventType === "toy") return 0.14;
    if (eventType === "praise") return 0.2;
    if (eventType === "scold") return -0.2;
    if (eventType === "observe") return 0.07;
    if (eventType === "observe-feedback") return 0.06;
    return 0;
  }

  function adjustChemistryForOutcome(chemistry, eventType, feedback) {
    if (eventType === "food") {
      chemistry.hunger -= 42;
      chemistry.glucose += 34;
      chemistry.satiety += 38;
      chemistry.reward += 8;
    } else if (eventType === "toy") {
      chemistry.curiosity -= 45;
      chemistry.reward += 8;
      chemistry.arousal -= 12;
    } else if (eventType === "praise") {
      chemistry.reward += 12;
      chemistry.stress -= 6;
    } else if (eventType === "scold") {
      chemistry.punishment += 12;
      chemistry.stress += 8;
    } else if (eventType === "observe-feedback" && feedback === "praise") {
      chemistry.reward += 3;
      chemistry.stress -= 1;
    } else if (eventType === "observe-feedback" && feedback === "scold") {
      chemistry.punishment += 3;
      chemistry.stress += 2;
    } else if (["observe", "observe-feedback", "teach", "hear", "command", "word"].includes(eventType)) {
      chemistry.socialComfort += 1.5;
    }
    for (const name of CHEMICAL_NAMES) chemistry[name] = clamp(chemistry[name], 0, 100);
  }

  function recordOutcome(state, outcome = {}) {
    if (!state || !state.chemistry) return null;
    const eventType = typeof outcome.eventType === "string" ? outcome.eventType : "experience";
    const actionId = ACTION_IDS.includes(outcome.actionId) ? outcome.actionId : null;
    const targetId = typeof outcome.targetId === "string" ? outcome.targetId : null;
    const before = copyChemistry(state.chemistry);
    const peerCount = Math.max(0, Math.floor(finiteOr(outcome.peerCount, 0)));
    const contexts = getContextIds(before, peerCount);
    adjustChemistryForOutcome(state.chemistry, eventType, outcome.feedback);

    let learningDelta = deriveLearningDelta(eventType, outcome.learningDelta);
    if (eventType === "observe" && Number.isFinite(outcome.sociability)) {
      learningDelta = 0.06 + clamp(outcome.sociability, 0, 1) * 0.04;
    } else if (eventType === "observe-feedback" && Number.isFinite(outcome.sociability)) {
      learningDelta = (outcome.feedback === "scold" ? -1 : 1)
        * (0.04 + clamp(outcome.sociability, 0, 1) * 0.03);
    }

    for (const id of ACTION_IDS) {
      state.eligibility[id] = clamp(state.eligibility[id] * 0.88, 0, 1);
      for (const contextId of CONTEXT_IDS) {
        state.contextEligibility[id][contextId] = clamp(state.contextEligibility[id][contextId] * 0.88, 0, 1);
      }
    }
    if (actionId) {
      state.eligibility[actionId] = 1;
      for (const contextId of contexts) state.contextEligibility[actionId][contextId] = 1;
    }
    const valence = eventType === "scold" || eventType === "observe-feedback" && outcome.feedback === "scold"
      ? -1
      : ["food", "toy", "praise", "observe", "observe-feedback"].includes(eventType) ? 1 : 0;
    if (actionId && learningDelta !== 0) {
      state.actionAssociations[actionId] = clamp(
        state.actionAssociations[actionId] + learningDelta,
        0,
        1
      );
      for (const contextId of contexts) {
        state.contextAssociations[actionId][contextId] = clamp(
          state.contextAssociations[actionId][contextId] + learningDelta * 0.5,
          0,
          1
        );
      }
    }
    const rewardSignal = clamp(finiteOr(outcome.reward, valence), -1, 1);
    if (rewardSignal !== 0) {
      let remainingChange = Math.max(0, 0.2 - Math.abs(learningDelta));
      const traceOrder = actionId ? [actionId, ...ACTION_IDS.filter(id => id !== actionId)] : ACTION_IDS;
      for (const id of traceOrder) {
        const trace = state.eligibility[id];
        const change = clamp(rewardSignal * trace * 0.04, -remainingChange, remainingChange);
        if (change !== 0) {
          state.actionAssociations[id] = clamp(state.actionAssociations[id] + change, 0, 1);
          remainingChange = Math.max(0, remainingChange - Math.abs(change));
        }
      }
      let remainingContextChange = Math.max(0, 0.1 - Math.abs(learningDelta * 0.5));
      for (const id of traceOrder) {
        for (const contextId of contexts) {
          const trace = state.contextEligibility[id][contextId];
          const change = clamp(rewardSignal * trace * 0.02, -remainingContextChange, remainingContextChange);
          if (change !== 0) {
            state.contextAssociations[id][contextId] = clamp(
              state.contextAssociations[id][contextId] + change,
              0,
              1
            );
            remainingContextChange = Math.max(0, remainingContextChange - Math.abs(change));
          }
        }
      }
    }

    const episode = {
      id: state.nextEpisodeId++,
      time: Math.max(0, finiteOr(outcome.time, 0)),
      observation: {
        hunger: before.hunger,
        curiosity: before.curiosity,
        fatigue: before.fatigue,
        peerCount
      },
      actorId: typeof outcome.actorId === "string" ? outcome.actorId.slice(0, 32) : null,
      actionId,
      targetId,
      chemicalsBefore: before,
      chemicalsAfter: copyChemistry(state.chemistry),
      outcome: eventType,
      eventType,
      linkedEventId: Number.isInteger(outcome.eventId) && outcome.eventId > 0 ? outcome.eventId : null,
      salience: clamp(finiteOr(outcome.salience, eventType === "food" || eventType === "toy" ? 0.9 : 0.55), 0, 1),
      valence,
      text: typeof outcome.text === "string" ? outcome.text.slice(0, 500) : "",
      word: typeof outcome.word === "string" ? outcome.word.slice(0, 24) : null
    };
    state.episodes.push(episode);
    if (state.episodes.length > EPISODE_LIMIT) state.episodes.splice(0, state.episodes.length - EPISODE_LIMIT);
    return {
      episodeId: episode.id,
      actionId,
      association: actionId ? state.actionAssociations[actionId] : null,
      learningDelta
    };
  }

  function serialize(state) {
    if (!state) return null;
    return {
      version: VERSION,
      seed: state.seed,
      traits: { ...state.traits },
      chemistry: copyChemistry(state.chemistry),
      actionAssociations: { ...state.actionAssociations },
      contextAssociations: Object.fromEntries(ACTION_IDS.map(actionId => [
        actionId, { ...state.contextAssociations[actionId] }
      ])),
      episodes: state.episodes.map(episode => ({
        ...episode,
        observation: { ...episode.observation },
        chemicalsBefore: { ...episode.chemicalsBefore },
        chemicalsAfter: { ...episode.chemicalsAfter }
      })),
      nextEpisodeId: state.nextEpisodeId,
      eligibility: { ...state.eligibility },
      contextEligibility: Object.fromEntries(ACTION_IDS.map(actionId => [
        actionId, { ...state.contextEligibility[actionId] }
      ])),
      recurrent: {
        hidden: Array.from(state.hidden),
        decisionCount: state.decisionCount
      },
      commitmentUntil: state.commitmentUntil,
      lastDecision: structuredCloneDecision(state.lastDecision)
    };
  }

  function validChemistry(value) {
    return value && typeof value === "object"
      && CHEMICAL_NAMES.every(name => Number.isFinite(value[name]) && value[name] >= 0 && value[name] <= 100);
  }

  function validContextMap(value, low = 0, high = 1) {
    return value && typeof value === "object"
      && ACTION_IDS.every(actionId => value[actionId] && CONTEXT_IDS.every(contextId =>
        Number.isFinite(value[actionId][contextId])
        && value[actionId][contextId] >= low && value[actionId][contextId] <= high));
  }

  function validEpisode(episode, maxEventId) {
    return episode && typeof episode === "object"
      && Number.isInteger(episode.id) && episode.id > 0
      && Number.isFinite(episode.time) && episode.time >= 0
      && episode.observation && typeof episode.observation === "object"
      && Number.isFinite(episode.observation.hunger) && episode.observation.hunger >= 0 && episode.observation.hunger <= 100
      && Number.isFinite(episode.observation.curiosity) && episode.observation.curiosity >= 0 && episode.observation.curiosity <= 100
      && Number.isFinite(episode.observation.fatigue) && episode.observation.fatigue >= 0 && episode.observation.fatigue <= 100
      && Number.isInteger(episode.observation.peerCount) && episode.observation.peerCount >= 0 && episode.observation.peerCount <= 4
      && (episode.actorId === null || typeof episode.actorId === "string" && episode.actorId.length <= 32)
      && (episode.actionId === null || ACTION_IDS.includes(episode.actionId))
      && (episode.targetId === null || ["fruit", "spinner", "praise", "scold"].includes(episode.targetId))
      && validChemistry(episode.chemicalsBefore) && validChemistry(episode.chemicalsAfter)
      && typeof episode.outcome === "string" && episode.outcome.length <= 40
      && typeof episode.eventType === "string" && episode.eventType.length <= 40
      && (episode.linkedEventId === null || Number.isInteger(episode.linkedEventId)
        && episode.linkedEventId > 0 && episode.linkedEventId < maxEventId)
      && Number.isFinite(episode.salience) && episode.salience >= 0 && episode.salience <= 1
      && [-1, 0, 1].includes(episode.valence)
      && typeof episode.text === "string" && episode.text.length <= 500
      && (episode.word === null || typeof episode.word === "string" && episode.word.length <= 24);
  }

  function validDecision(decision) {
    return decision && typeof decision === "object"
      && ACTION_IDS.includes(decision.actionId)
      && decision.actionScores && ACTION_IDS.every(actionId => Number.isFinite(decision.actionScores[actionId]))
      && typeof decision.reason === "string" && decision.reason.length <= 240
      && Array.isArray(decision.recalledEpisodeIds) && decision.recalledEpisodeIds.length <= 3
      && decision.recalledEpisodeIds.every(id => Number.isInteger(id) && id > 0)
      && decision.components && [
        "fruitNeed", "fruitHabit", "fruitContext", "fruitScore",
        "spinnerNeed", "spinnerHabit", "spinnerContext", "spinnerScore",
        "restNeed", "observeNeed"
      ].every(name => Number.isFinite(decision.components[name]));
  }

  function restore(record) {
    if (!record || typeof record !== "object" || record.version !== VERSION
      || !Number.isInteger(record.seed) || record.seed < 0 || record.seed > 0xffffffff
      || !record.traits || !Number.isFinite(record.traits.curiosity) || record.traits.curiosity < 0 || record.traits.curiosity > 1
      || !Number.isFinite(record.traits.sociability) || record.traits.sociability < 0 || record.traits.sociability > 1
      || !validChemistry(record.chemistry)
      || !record.actionAssociations || !ACTION_IDS.every(id => Number.isFinite(record.actionAssociations[id])
        && record.actionAssociations[id] >= 0 && record.actionAssociations[id] <= 1)
      || !validContextMap(record.contextAssociations)
      || !Array.isArray(record.episodes) || record.episodes.length > EPISODE_LIMIT
      || !Number.isInteger(record.nextEpisodeId) || record.nextEpisodeId < 1
      || !record.eligibility || !ACTION_IDS.every(id => Number.isFinite(record.eligibility[id])
        && record.eligibility[id] >= 0 && record.eligibility[id] <= 1)
      || !validContextMap(record.contextEligibility)
      || !record.recurrent || !Array.isArray(record.recurrent.hidden) || record.recurrent.hidden.length !== RECURRENT_UNITS
      || !record.recurrent.hidden.every(value => Number.isFinite(value) && value >= -1 && value <= 1)
      || !Number.isInteger(record.recurrent.decisionCount) || record.recurrent.decisionCount < 0
      || !Number.isFinite(record.commitmentUntil) || record.commitmentUntil < 0
      || !record.episodes.every(episode => validEpisode(episode, Number.MAX_SAFE_INTEGER))
      || new Set(record.episodes.map(episode => episode && episode.id)).size !== record.episodes.length
      || record.episodes.some(episode => episode.id >= record.nextEpisodeId)
      || record.lastDecision !== null && !validDecision(record.lastDecision)) return null;

    const state = createState(record.seed, record.traits, {
      hunger: record.chemistry.hunger,
      curiosity: record.chemistry.curiosity,
      fatigue: record.chemistry.fatigue,
      actionAssociations: record.actionAssociations
    });
    state.chemistry = copyChemistry(record.chemistry);
    state.contextAssociations = normalizeContextMap(record.contextAssociations);
    state.episodes = record.episodes.map(episode => ({
      ...episode,
      observation: { ...episode.observation },
      chemicalsBefore: { ...episode.chemicalsBefore },
      chemicalsAfter: { ...episode.chemicalsAfter }
    }));
    state.nextEpisodeId = record.nextEpisodeId;
    state.eligibility = Object.fromEntries(ACTION_IDS.map(id => [id, record.eligibility[id]]));
    state.contextEligibility = normalizeContextMap(record.contextEligibility, 0);
    state.hidden = Float32Array.from(record.recurrent.hidden);
    state.decisionCount = record.recurrent.decisionCount;
    state.commitmentUntil = record.commitmentUntil;
    state.lastDecision = record.lastDecision ? structuredCloneDecision(record.lastDecision) : null;
    return state;
  }

  root.NornCognition = Object.freeze({
    version: VERSION,
    chemicalNames: CHEMICAL_NAMES,
    actionIds: ACTION_IDS,
    contextIds: CONTEXT_IDS,
    episodeLimit: EPISODE_LIMIT,
    recurrentUnits: RECURRENT_UNITS,
    reactionTable: REACTION_TABLE,
    createState,
    advanceChemistry,
    decide,
    preview,
    recordOutcome,
    serialize,
    restore
  });
})(typeof window === "object" ? window : globalThis);
