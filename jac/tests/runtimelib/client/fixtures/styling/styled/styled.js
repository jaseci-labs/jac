import styled from "styled-components";

export const Container = styled.div`
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 1rem;
`;

export const CountDisplay = styled.div`
    font-size: 3.75rem;
    font-weight: bold;
    color: ${props => props.count > 0 ? "#16a34a" : "#dc2626"};
`;

export const Button = styled.button`
    color: #ffffff;
    font-weight: bold;
    padding: 0.75rem 1.5rem;
    border-radius: 0.5rem;
    border: none;
    cursor: pointer;
    background-color: ${props => props.bgColor};
`;
