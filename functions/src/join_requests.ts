/** Returns the company to notify, or null when this is not a join request. */
export function joinRequestCompanyId(
  profile: Record<string, unknown>,
  hasCompanyBan: boolean,
): string | null {
  if (profile.membership !== 'pending' || hasCompanyBan) return null;
  const companyId = profile.companyId;
  return typeof companyId === 'string' && companyId.trim().length > 0
    ? companyId
    : null;
}
