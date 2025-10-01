<!--
Sync Impact Report:
Version: 0.0.0 → 1.0.0
Initial constitution created for SudokuVersus project
Principles established:
  1. Phoenix v1.8 Best Practices
  2. Elixir 1.18 Idiomatic Code
  3. Test-First Development
  4. LiveView-Centric Architecture
  5. Clean & Modular Design
Added sections:
  - Core Principles (5 principles)
  - Development Standards
  - Quality Gates
  - Governance
Templates requiring updates:
  ✅ plan-template.md - Constitution Check section will reference these principles
  ✅ spec-template.md - Aligned with testability and clarity requirements
  ✅ tasks-template.md - TDD phase aligns with Principle III
  ✅ AGENTS.md - This file serves as the runtime guidance document
Follow-up TODOs: None
-->

# SudokuVersus Constitution

## Core Principles

### I. Phoenix v1.8 Best Practices (NON-NEGOTIABLE)

**Rules:**
- **MUST** use Phoenix LiveView for interactive features; avoid JavaScript where LiveView suffices
- **MUST** use `~H` sigil or `.html.heex` files for all templates; `~E` is forbidden
- **MUST** use `to_form/2` for form assignments in LiveView; **NEVER** pass raw changesets to templates
- **MUST** use `<.form for={@form}>` in templates with `<.input field={@form[:field]}>` components from `core_components.ex`
- **MUST** use `<Layouts.app flash={@flash}>` wrapper in all LiveView templates
- **MUST** use `<.link navigate={}>` and `<.link patch={}>` for navigation; `live_redirect` and `live_patch` are deprecated
- **MUST** use LiveView streams (`stream/3`, `stream_delete/2`) for collections to prevent memory issues
- **MUST** use `<.icon name="hero-x-mark">` component for icons; never import Heroicons modules directly
- **MUST** preload Ecto associations in queries when accessed in templates
- **MUST** avoid LiveComponents unless there is a strong, specific need

**Rationale:** Phoenix v1.8 introduced significant API changes and best practices. Following these ensures compatibility, performance, and maintainability while leveraging the framework's full power.

### II. Elixir 1.18 Idiomatic Code (NON-NEGOTIABLE)

**Rules:**
- **MUST** use `Enum.at/2` or pattern matching for list access; bracket syntax `list[i]` is invalid in Elixir
- **MUST** bind block expression results to variables; cannot rebind inside expressions:
  ```elixir
  # VALID
  socket = if connected?(socket), do: assign(socket, :val, val)

  # INVALID
  if connected?(socket) do
    socket = assign(socket, :val, val)  # This rebinding is lost
  end
  ```
- **MUST** access struct fields directly (`struct.field`) or use appropriate APIs (`Ecto.Changeset.get_field/2`); never use map access syntax on structs
- **MUST** use built-in `DateTime`, `Date`, `Time`, `Calendar` modules for date/time operations
- **NEVER** use `String.to_atom/1` on user input (memory leak risk)
- **MUST** name predicate functions with `?` suffix (not `is_` prefix); reserve `is_` for guards
- **MUST** use `Task.async_stream/3` with `timeout: :infinity` for concurrent enumeration with back-pressure
- **MUST** provide explicit names in OTP child specs: `{DynamicSupervisor, name: MyApp.MySup}`
- **NEVER** nest multiple modules in the same file (causes cyclic dependencies)

**Rationale:** Elixir's immutability, functional paradigm, and OTP patterns require specific idioms. Following these prevents common bugs and ensures code behaves as expected.

### III. Test-First Development (NON-NEGOTIABLE)

**Rules:**
- **MUST** write tests before implementation (Red-Green-Refactor cycle)
- **MUST** use `Phoenix.LiveViewTest` for LiveView testing with `element/2`, `has_element/2`, never raw HTML assertions
- **MUST** add unique DOM IDs to key template elements for test selection (`id="product-form"`)
- **MUST** run `mix precommit` before commits; all warnings treated as errors
- **MUST** test outcomes, not implementation details
- **MUST** use `LazyHTML` for HTML debugging in failing tests
- **MUST** focus on key element presence over text content matching
- **MUST** use `mix test path/to/test.exs` for focused debugging or `mix test --failed` for regression testing

**Rationale:** Tests document intent, catch regressions early, and enable confident refactoring. The precommit alias ensures code quality gates are passed before changes are committed.

### IV. LiveView-Centric Architecture

**Rules:**
- **MUST** use LiveView for interactive UI; only add JavaScript hooks when necessary
- **MUST** write JS hooks in `assets/js/` directory, never inline `<script>` tags in HEEx
- **MUST** set `phx-update="ignore"` when JS hooks manage their own DOM
- **MUST** use streams for collections with `phx-update="stream"` and proper DOM IDs:
  ```heex
  <div id="messages" phx-update="stream">
    <div :for={{id, msg} <- @streams.messages} id={id}>
      {msg.text}
    </div>
  </div>
  ```
- **MUST** refetch and reset streams (`reset: true`) for filtering/pruning; streams are not enumerable
- **MUST** track empty states and counts separately; streams don't support these natively
- **MUST** use `push_navigate` and `push_patch` in LiveView modules for programmatic navigation
- **MUST** handle forms with `phx-change` for validation and `phx-submit` for submission

**Rationale:** LiveView enables rich interactivity with minimal JavaScript while maintaining server-side logic. Proper stream usage prevents memory issues at scale.

### V. Clean & Modular Design

**Rules:**
- **MUST** follow the "Clean and modular code" directive from AGENTS.md
- **MUST** separate concerns: contexts for business logic, schemas for data, LiveViews for presentation
- **MUST** use the `Req` library for HTTP requests; avoid `:httpoison`, `:tesla`, `:httpc`
- **MUST** keep LiveView mount/handle callbacks focused; extract complex logic to context functions
- **MUST** use Phoenix router `scope` blocks with proper aliasing; avoid redundant module prefixes
- **MUST** document complex business logic with module and function docs
- **MUST** follow YAGNI (You Aren't Gonna Need It); start simple, add complexity only when needed
- **MUST** use descriptive variable and function names; avoid abbreviations unless domain-standard

**Rationale:** Clean, modular code is easier to understand, test, and maintain. Separation of concerns enables independent testing and evolution of components.

## Development Standards

### HEEx Template Guidelines

- **MUST** use `{...}` for attribute interpolation and simple value interpolation in tag bodies
- **MUST** use `<%= ... %>` for block constructs (`if`, `cond`, `case`, `for`) in tag bodies
- **MUST** use `cond` or `case` for multiple conditions; Elixir has no `else if` or `elsif`
- **MUST** use list syntax for conditional classes: `class={["base", @flag && "extra"]}`
- **MUST** wrap inline `if` in class lists with parens: `if(@cond, do: "class-a", else: "class-b")`
- **MUST** use `<%!-- comment --%>` for HEEx comments
- **MUST** use `phx-no-curly-interpolation` on tags containing literal `{` or `}` (e.g., code blocks)
- **MUST** use `<%= for item <- @collection do %>` for iteration; never `<% Enum.each %>`

### Ecto Guidelines

- **MUST** use `:string` type in schemas even for `:text` columns
- **MUST** use `Ecto.Changeset.get_field/2` to access changeset fields; never map access syntax
- **MUST** exclude programmatically-set fields from `cast/3` calls; set them explicitly for security
- **NEVER** use `validate_number/2` with `:allow_nil` option (doesn't exist; validations skip nil by default)
- **MUST** preload associations before template access to avoid N+1 queries

### Mix & Dependency Management

- **MUST** run `mix help task_name` to understand task options before use
- **MUST** use `mix test test/path.exs` for focused test runs
- **MUST** use `mix test --failed` to rerun only failed tests
- **AVOID** `mix deps.clean --all` unless absolutely necessary
- **MUST** keep dependencies in `mix.exs` deps list; Req is already included

### Router & Scope Guidelines

- **MUST** leverage scope aliasing; avoid redundant prefixes in route definitions:
  ```elixir
  scope "/admin", SudokuVersusWeb.Admin do
    live "/users", UserLive  # Routes to SudokuVersusWeb.Admin.UserLive
  end
  ```
- **MUST** name LiveViews with `Live` suffix (e.g., `GameLive`, `LobbyLive`)

## Quality Gates

### Pre-Commit Requirements (Enforced by `mix precommit`)

1. **Compilation**: Code must compile with all warnings treated as errors
2. **Dependencies**: Unused dependencies must be unlocked
3. **Formatting**: Code must pass `mix format` checks
4. **Tests**: All tests must pass

**Enforcement:** The `mix precommit` alias runs these checks automatically. All must pass before committing.

### Code Review Requirements

- **Constitution Compliance**: Reviewer must verify adherence to all NON-NEGOTIABLE principles
- **Test Coverage**: All new features must have corresponding tests written first
- **Template Quality**: HEEx templates must follow interpolation and structure rules
- **Performance**: LiveView streams must be used for collections; associations must be preloaded
- **Documentation**: Complex business logic must have explanatory comments or docs

### Testing Standards

- **Unit Tests**: Test pure functions and business logic in isolation
- **Integration Tests**: Test Ecto queries, context functions, and cross-boundary interactions
- **LiveView Tests**: Test user interactions, form submissions, and UI state changes
- **Contract Tests**: If exposing APIs, test request/response contracts

## Governance

### Amendment Process

1. **Proposal**: Document proposed change with rationale and impact analysis
2. **Review**: Team reviews for necessity, clarity, and alignment with project goals
3. **Approval**: Requires consensus or designated approver sign-off
4. **Migration**: Update this document, dependent templates, and guidance files
5. **Communication**: Announce changes and update dates below

### Versioning Policy

- **MAJOR** (X.0.0): Backward-incompatible principle removals or redefinitions
- **MINOR** (x.Y.0): New principles added or existing principles materially expanded
- **PATCH** (x.y.Z): Clarifications, wording improvements, non-semantic fixes

### Compliance Review

- Constitution supersedes all other development practices
- All PRs must verify compliance with NON-NEGOTIABLE principles
- Complexity or deviations must be explicitly justified and approved
- Use `AGENTS.md` for detailed runtime development guidance
- Template files in `.specify/templates/` must align with these principles

### Guidance Documents

- **Runtime Guidance**: `/Users/rocket4ce/sites/elixir/sudoku_versus/AGENTS.md`
- **Plan Template**: `.specify/templates/plan-template.md`
- **Spec Template**: `.specify/templates/spec-template.md`
- **Tasks Template**: `.specify/templates/tasks-template.md`

**Version**: 1.0.0 | **Ratified**: 2025-10-01 | **Last Amended**: 2025-10-01