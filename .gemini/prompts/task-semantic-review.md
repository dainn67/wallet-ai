# Task Semantic Review — Task #{N}

Before closing this task, complete this self-review checklist.

## Spec Compliance
- [ ] Code implements ALL acceptance criteria from the issue? (compare with issue description)
- [ ] No extra functionality beyond what was requested? (scope creep check)
- [ ] If design file exists → implementation matches the documented approach?

## Integration Safety
- [ ] Interfaces with other modules changed? → If YES: consumers checked, interfaces documented?
- [ ] Shared files (utilities, configs, types) modified? → If YES: all usages grep'd and verified?

## Quality
- [ ] Error handling for edge cases present?
- [ ] Hard-coded values that should be configurable?
- [ ] Comments explain WHY for non-obvious logic?

## Instructions
- Answer YES or NO for each item
- If ANY answer is NO → add to handoff note under "## Warnings for Next Task"
- If ALL answers are YES → proceed to close
- This is a self-review. No additional code execution needed.
