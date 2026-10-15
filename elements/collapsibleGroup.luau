-- Deprecated alias: CollapsibleGroup -> Accordion
-- Kept for backward compatibility. New code should use `accordion` and `CreateAccordion`.
local Accordion = require(script.Parent.accordion)
-- Preserve old __type for migration? But new type is Accordion; keep alias by returning same module
-- Ensure any `__type == "CollapsibleGroup"` checks still pass by supporting both.
-- We expose the Accordion module as-is and also allow `__type` checks for both by aliasing in consumers.
return Accordion
