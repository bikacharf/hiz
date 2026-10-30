# Codex Cloud runbook

## Operating loop

1. Read repository instructions and current status.
2. Work only on the active milestone.
3. Inspect existing code and tests before changing files.
4. Make the smallest coherent implementation that advances the acceptance criteria.
5. Run the milestone validation commands.
6. Fix failures before adding scope.
7. Update `docs/STATUS.md` with evidence and unresolved risks.
8. Stop when the milestone is verified or when a listed blocked condition is reached.

## Required reporting

Every Cloud task must report:

- files changed
- behavior added or corrected
- exact validation commands and results
- unverified claims
- licensing additions or changes
- device/Mac checks still required
- next recommended task

## Stop conditions

Stop and request user input when:

- a proprietary or unclear-license model is necessary
- an external paid service is proposed
- a credential, signing key, store account, or personal test recording is required
- a destructive repository operation is needed
- the task would merge, publish, deploy, or submit to a store
- evidence does not support the requested accuracy claim
- iOS completion depends on a Mac/device result that is unavailable

## Review policy

- Passing compilation is not sufficient for camera or measurement claims.
- A quality score is not an accuracy score.
- Mock data and mocked platform behavior must be labeled.
- Never silently replace a failed live integration with a simulation.
- Preserve raw evidence and provenance for validation fixtures without committing private recordings.

