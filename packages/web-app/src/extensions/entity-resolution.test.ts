// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

import { describe, it, expect } from "vitest";
import { formatStepDetail } from "@components/Chat/RationalePanel/format-step-detail";
import { STEP_DISPLAY_NAMES } from "@components/Chat/step-labels";
import { ENTITY_STEP_ID, formatEntityStep } from "./entity-resolution";

describe("entity-resolution extension", () => {
  it("lists any configured entity types", () => {
    expect(
      formatEntityStep({
        status: "found",
        entities: { company: ["Bajaj Auto Ltd."], product: ["Widget"] },
      }),
    ).toBe("Resolved company: Bajaj Auto Ltd.; product: Widget.");
  });

  it("says why the step was skipped", () => {
    expect(
      formatEntityStep({ status: "skipped", reason: "entity index empty" }),
    ).toBe("Skipped (entity index empty).");
  });

  it("is wired into the upstream step labels and formatter", () => {
    expect(STEP_DISPLAY_NAMES[ENTITY_STEP_ID]).toBe("Resolve entities");
    expect(
      formatStepDetail(ENTITY_STEP_ID, {
        status: "no_entity",
        entities: {},
      }),
    ).toBe("No specific entity named in the question.");
  });
});
