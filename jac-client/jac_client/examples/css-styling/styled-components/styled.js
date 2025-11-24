import styled from "styled-components";

export const Container = styled.div`
    min-height: 100vh;
    background: linear-gradient(to bottom right, #dbeafe, #e0e7ff);
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 1rem;
`;

export const Card = styled.div`
    background-color: #ffffff;
    border-radius: 1rem;
    box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
    padding: 2rem;
    max-width: 28rem;
    width: 100%;
`;

export const Title = styled.h1`
    font-size: 1.875rem;
    font-weight: bold;
    color: #1f2937;
    text-align: center;
    margin-bottom: 1.5rem;
`;

export const Divider = styled.div`
    height: 1px;
    background: linear-gradient(to right, transparent, #d1d5db, transparent);
    margin-bottom: 1.5rem;
`;

export const CounterSection = styled.div`
    text-align: center;
    margin-bottom: 2rem;
`;

export const Label = styled.div`
    font-size: 0.875rem;
    font-weight: 600;
    color: #4b5563;
    margin-bottom: 0.5rem;
    text-transform: uppercase;
    letter-spacing: 0.05em;
`;

export const CountDisplay = styled.div`
    font-size: 3.75rem;
    font-weight: bold;
    transition: color 0.3s ease;
    color: ${props => props.count === 0 ? "#1f2937" : (props.count > 0 ? "#16a34a" : "#dc2626")};
`;

export const ButtonGroup = styled.div`
    display: flex;
    justify-content: center;
    align-items: center;
    gap: 1rem;
    margin-bottom: 1.5rem;
`;

export const Button = styled.button`
    color: #ffffff;
    font-weight: bold;
    padding: 0.75rem 1.5rem;
    border-radius: 0.5rem;
    box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
    transition: all 0.2s ease;
    font-size: 1.25rem;
    border: none;
    cursor: pointer;
    background-color: ${props => props.bgColor};

    &:hover {
        transform: scale(1.05);
    }

    &:active {
        transform: scale(0.95);
    }
`;

export const Hint = styled.div`
    text-align: center;
    font-size: 0.875rem;
    color: #6b7280;
    font-style: italic;
`;

