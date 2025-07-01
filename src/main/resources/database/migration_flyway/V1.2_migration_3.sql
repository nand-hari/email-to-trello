CREATE TABLE emails (
    id SERIAL PRIMARY KEY,
    from_address VARCHAR(255) NOT NULL,
    to_address VARCHAR(255) NOT NULL,
    subject TEXT,
    body TEXT,
    received_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
