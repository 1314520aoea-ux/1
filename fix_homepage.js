export default async function(ctx) {
  const data = await ctx.response.json();
  return { body: JSON.stringify(data) };
}
