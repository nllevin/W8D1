PRAGMA foreign_keys = ON;


DROP TABLE IF EXISTS replies;
DROP TABLE IF EXISTS question_follows;
DROP TABLE IF EXISTS question_likes;
DROP TABLE IF EXISTS questions;
DROP TABLE IF EXISTS users;

CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  fname TEXT NOT NULL,
  lname TEXT NOT NULL
);  

CREATE TABLE questions (
  id INTEGER PRIMARY KEY,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  user_id INTEGER NOT NULL,

  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE question_follows (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL,
  question_id INTEGER NOT NULL,

  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (question_id) REFERENCES questions(id)
);

CREATE TABLE replies (
  id INTEGER PRIMARY KEY,
  question_id INTEGER NOT NULL,
  parent_id INTEGER,
  user_id INTEGER NOT NULL,
  body TEXT NOT NULL,

  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (question_id) REFERENCES questions(id),
  FOREIGN KEY (parent_id) REFERENCES replies(id)
);

CREATE TABLE question_likes (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL,
  question_id INTEGER NOT NULL,

  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (question_id) REFERENCES questions(id)
);


INSERT INTO
  users (fname, lname)
VALUES
  ('Noah', 'Levin'),
  ('Jordan', 'Ackerman');

INSERT INTO
  questions (title, body, user_id)
VALUES
  ('Silly Question', 'I am asking a silly question', 1),
  ('Silly Question 2', 'I am asking a silly question, but mine has more detail', 2);

INSERT INTO
  question_follows (user_id, question_id)
VALUES
  (1, 2),
  (2, 1);

INSERT INTO
  replies (question_id, parent_id, user_id, body)
VALUES
  (1, NULL, 2, 'Very silly question, I reply with another question!'),
  (1, 1, 1, 'Great question, not silly enough!');

INSERT INTO
  question_likes (user_id, question_id)
VALUES
  (1, 2),
  (2, 1),
  (2, 2);

