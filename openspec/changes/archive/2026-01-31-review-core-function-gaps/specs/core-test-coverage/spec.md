## ADDED Requirements

### Requirement: Core tests define coverage scope
The system SHALL define the coverage scope for core modules, including config, timer, ipc, and main, and document high-risk paths that must be tested.

#### Scenario: Coverage scope recorded
- **WHEN** a coverage review is performed
- **THEN** the scope lists config, timer, ipc, and main modules and highlights error and boundary paths

### Requirement: Core tests include error and boundary scenarios
The system SHALL include test cases that cover error paths and boundary inputs for each module in the defined coverage scope.

#### Scenario: Error and boundary tests present
- **WHEN** tests are executed for core modules
- **THEN** each module has at least one test that validates error handling or boundary inputs
