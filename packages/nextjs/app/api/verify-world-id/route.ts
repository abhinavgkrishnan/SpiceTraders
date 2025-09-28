import { NextRequest, NextResponse } from "next/server";

interface WorldIDProof {
  merkle_root: string;
  nullifier_hash: string;
  proof: string;
  verification_level: string;
  action: string;
  signal?: string;
}

export async function POST(req: NextRequest) {
  try {
    const { proof, action, signal }: { proof: WorldIDProof; action: string; signal?: string } = await req.json();

    if (!proof || !action) {
      return NextResponse.json(
        { success: false, error: "Missing required fields" },
        { status: 400 }
      );
    }

    // TODO: Implement actual World ID proof verification
    // This would typically involve:
    // 1. Verifying the proof against the merkle root
    // 2. Checking that the nullifier hasn't been used before
    // 3. Validating the action matches what was expected
    // 4. Storing the nullifier to prevent replay attacks

    // For now, we'll do basic validation
    if (!proof.merkle_root || !proof.nullifier_hash || !proof.proof) {
      return NextResponse.json(
        { success: false, error: "Invalid proof format" },
        { status: 400 }
      );
    }

    // In a real implementation, you would:
    // 1. Call the World ID verification API
    // 2. Check against your database for nullifier reuse
    // 3. Store the verification result

    console.log("World ID verification request:", {
      action,
      signal,
      merkle_root: proof.merkle_root,
      nullifier_hash: proof.nullifier_hash,
      verification_level: proof.verification_level,
    });

    // Simulate verification success
    return NextResponse.json({
      success: true,
      verified: true,
      action,
      nullifier_hash: proof.nullifier_hash,
    });
  } catch (error) {
    console.error("World ID verification error:", error);
    return NextResponse.json(
      { success: false, error: "Internal server error" },
      { status: 500 }
    );
  }
}
