let counter = 0;

export const nextId = () => {
  counter += 1;
  return `w${counter}`;
};
