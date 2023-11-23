-- Challenge 1 - Most Profiting Authors

-- Step 1: Calculate the royalties of each sales for each author
SELECT
    t.title_id,
    ta.au_id AS author_id,
    (t.price * s.qty * t.royalty / 100 * ta.royaltyper / 100) AS sales_royalty
FROM
    titles t
JOIN
    sales s ON t.title_id = s.title_id
JOIN
    titleauthor ta ON t.title_id = ta.title_id;

-- Step 2: Aggregate the total royalties for each title for each author

SELECT
    title_id,
    author_id,
    SUM(sales_royalty) AS aggregated_royalties
FROM
    (
        SELECT
            t.title_id,
            ta.au_id AS author_id,
            (t.price * s.qty * t.royalty / 100 * ta.royaltyper / 100) AS sales_royalty
        FROM
            titles t
        JOIN
            sales s ON t.title_id = s.title_id
        JOIN
            titleauthor ta ON t.title_id = ta.title_id
    ) AS derived_table
GROUP BY
    title_id,
    author_id;

-- Step 3: Calculate the total profits of each author

SELECT
    author_id,
    SUM(advance) + SUM(aggregated_royalties) AS total_profits
FROM
    ( -- Subquery to aggregate royalties from Step 2
        SELECT
            ta.au_id AS author_id,
            t.advance,
            COALESCE(SUM(sales_royalty), 0) AS aggregated_royalties
        FROM
            titles t
        JOIN
            titleauthor ta ON t.title_id = ta.title_id
        LEFT JOIN
            ( -- Subquery to calculate royalties from Step 1
                SELECT
                    s.title_id,
                    ta.au_id AS author_id,
                    ROUND(t.price * s.qty * t.royalty / 100 * ta.royaltyper / 100, 2) AS sales_royalty
                FROM
                    sales s
                JOIN
                    titles t ON s.title_id = t.title_id
                JOIN
                    titleauthor ta ON t.title_id = ta.title_id
            ) AS Step1Result ON t.title_id = Step1Result.title_id
        GROUP BY
            ta.au_id, t.advance
    ) AS Step2Result
GROUP BY
    author_id
ORDER BY
    total_profits DESC
LIMIT 3;

-- Challenge2: alternative solution

-- Step 1: Calculate the royalties of each sale for each author and store in a temporary table

CREATE TEMPORARY TABLE Step1Result AS
SELECT
    t.title_id,
    ta.au_id AS author_id,
    (t.price * s.qty * t.royalty / 100 * ta.royaltyper / 100) AS sales_royalty
FROM
    titles t
JOIN
    sales s ON t.title_id = s.title_id
JOIN
    titleauthor ta ON t.title_id = ta.title_id;
    
SELECT * FROM Step1Result;

-- Step 2: Aggregate the total royalties for each title for each author and store in a temporary table

CREATE TEMPORARY TABLE Step2Result AS
SELECT
    title_id,
    author_id,
    SUM(sales_royalty) AS aggregated_royalties
FROM
    Step1Result
GROUP BY
    title_id,
    author_id;

SELECT * FROM Step2Result;

-- Step 3: Calculate the total profits of each author using the temporary tables

DROP TEMPORARY TABLE IF EXISTS Step3Result;

CREATE TEMPORARY TABLE Step3Result AS
SELECT
    ta.au_id AS author_id,
    COALESCE(SUM(sr.aggregated_royalties) + SUM(t.advance), 0) AS total_profits
FROM
    titles t
JOIN
    titleauthor ta ON t.title_id = ta.title_id
LEFT JOIN
    Step2Result sr ON t.title_id = sr.title_id
GROUP BY
    ta.au_id
ORDER BY
    total_profits DESC
LIMIT 3;

SELECT * FROM Step3Result;

-- Challenge 3: Create the most_profiting_authors table

DROP  TABLE IF EXISTS most_profiting_authors;

CREATE TABLE most_profiting_authors (
    au_id VARCHAR(11) NOT NULL,
    profits DECIMAL(12, 2) NOT NULL,
    PRIMARY KEY (au_id)
);

ALTER TABLE most_profiting_authors
MODIFY COLUMN profits DECIMAL(15, 2);

-- Insert data into the most_profiting_authors table
INSERT INTO most_profiting_authors (au_id, profits)
SELECT
    ta.au_id,
    COALESCE(SUM(aggregated_royalties) + SUM(t.advance), 0) AS profits
FROM
    titles t
JOIN
    titleauthor ta ON t.title_id = ta.title_id
LEFT JOIN
    (
        SELECT
            title_id,
            author_id,
            SUM(sales_royalty) AS aggregated_royalties
        FROM
            (
                SELECT
                    t.title_id,
                    ta.au_id AS author_id,
                    (t.price * s.qty * t.royalty / 100 * ta.royaltyper / 100) AS sales_royalty
                FROM
                    titles t
                JOIN
                    sales s ON t.title_id = s.title_id
                JOIN
                    titleauthor ta ON t.title_id = ta.title_id
            ) AS Step1Result
        GROUP BY
            title_id,
            author_id
    ) AS Step2Result ON t.title_id = Step2Result.title_id
GROUP BY
    ta.au_id;
    
UPDATE most_profiting_authors
SET profits = (
    SELECT
        COALESCE(SUM(aggregated_royalties) + SUM(t.advance), 0) AS profits
    FROM
        titles t
    JOIN
        titleauthor ta ON t.title_id = ta.title_id
    LEFT JOIN
        (
            SELECT
                title_id,
                author_id,
                SUM(sales_royalty) AS aggregated_royalties
            FROM
                (
                    SELECT
                        t.title_id,
                        ta.au_id AS author_id,
                        (t.price * s.qty * t.royalty / 100 * ta.royaltyper / 100) AS sales_royalty
                    FROM
                        titles t
                    JOIN
                        sales s ON t.title_id = s.title_id
                    JOIN
                        titleauthor ta ON t.title_id = ta.title_id
                ) AS Step1Result
            GROUP BY
                title_id,
                author_id
        ) AS Step2Result ON t.title_id = Step2Result.title_id
    WHERE
        most_profiting_authors.au_id = ta.au_id
    GROUP BY
        ta.au_id
);

SELECT * FROM most_profiting_authors;
