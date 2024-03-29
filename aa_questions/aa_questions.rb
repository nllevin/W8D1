require 'singleton'
require 'SQLite3'

class QuestionsDatabase < SQLite3::Database
  include Singleton

  def initialize
    super("questions.db") 
    self.type_translation = true
    self.results_as_hash = true
  end
end

class SuperQ
  def self.find_by_id(id)
    table_name = self.table_name
    found_info = QuestionsDatabase.instance.execute(<<-SQL, id)
      SELECT
        *
      FROM
        #{table_name}
      WHERE
        #{table_name}.id = ?
    SQL
    self.new(found_info.first)
  end

  def self.all
    data = QuestionsDatabase.instance.execute("SELECT * FROM #{self.table_name}")
    data.map { |datum| self.new(datum) }
  end

  def self.to_s
    raise "should be overridden by child classes"
  end

  def self.where(options)
    vals = options.values
    where_str = options.keys.map{ |key| "#{key} = ?"}.join(" AND ")

    found_data = QuestionsDatabase.instance.execute(<<-SQL, *vals)
      SELECT
        *
      FROM
        #{self.table_name}
      WHERE
        #{where_str}
    SQL
    found_data.map { |datum| self.new(datum) }
  end

  def save
    table_name = self.class.table_name
    vars = self.instance_variables

    if self.id
      set_str = vars.drop(1).map {|var| "#{var.to_s[2..-1]} = #{self.instance_variable_get(var)}"}.join(", ")

      QuestionsDatabase.instance.execute(<<-SQL, self.id)
        UPDATE
          #{table_name}
        SET
          #{set_str}
        WHERE
          id = ?
      SQL
    else
      insert_str = vars.map {|var| "#{var.to_s[2..-1]}"}.join(", ")
      values_str = vars.map {|var| "#{self.instance_variable_get(var)}"}.join(", ")
      QuestionsDatabase.instance.execute(<<-SQL)
        INSERT INTO
          #{table_name} (#{insert_str})
        VALUES
          (#{values_str})
      SQL
      self.id = QuestionsDatabase.instance.last_insert_row_id
    end
  end
end

class User < SuperQ
  attr_accessor :id, :fname, :lname

  
  def self.find_by_name(fname, lname)
    found_info = QuestionsDatabase.instance.execute(<<-SQL, fname, lname)
      SELECT
        *
      FROM
        users
      WHERE
        users.fname = ? AND users.lname = ?
    SQL
    User.new(found_info.first)
  end

  def self.table_name
    "users"
  end

  def initialize(options)
    @id = options['id']
    @fname = options['fname']
    @lname = options['lname']
  end

  

  def authored_questions
    Question.find_by_author_id(self.id)
  end

  def authored_replies
    Reply.find_by_user_id(self.id)
  end

  def followed_questions
    QuestionFollow.followed_questions_for_user_id(self.id)
  end

  def liked_questions
    QuestionLike.liked_questions_for_user_id(self.id)
  end

  def average_karma
    num = QuestionsDatabase.instance.execute(<<-SQL, self.id)
      SELECT
        CAST(COUNT(question_likes.user_id) AS FLOAT) / COUNT(DISTINCT(questions.id)) AS avg_karma
      FROM
        questions
      INNER JOIN
        users ON users.id = questions.user_id
      LEFT OUTER JOIN
        question_likes ON questions.id = question_likes.question_id
      WHERE
        questions.user_id = ?
    SQL
    num.first["avg_karma"]
  end
end

class Question < SuperQ
  attr_accessor :id, :title, :body, :user_id


  def self.table_name
    "questions"
  end

  def self.find_by_author_id(author_id)
    found_data = QuestionsDatabase.instance.execute(<<-SQL, author_id)
      SELECT
        *
      FROM
        questions
      WHERE
        questions.user_id = ?
    SQL
    found_data.map { |datum| Question.new(datum) }
  end

  def self.most_followed(n)
    QuestionFollow.most_followed_questions(n)
  end

  def self.most_liked(n)
    QuestionLike.most_liked_questions(n)
  end

  def initialize(options)
    @id = options['id']
    @title = options['title']
    @body = options['body']
    @user_id = options['user_id']
  end

  def author
    User.find_by_id(self.user_id)
  end

  def replies
    Reply.find_by_question_id(self.id)
  end

  def followers
    QuestionFollow.followers_for_question_id(self.id)
  end

  def likers
    QuestionLike.likers_for_question_id(self.id)
  end

  def num_likes
    QuestionLike.num_likes_for_question_id(self.id)
  end

  
end

class QuestionFollow < SuperQ
  attr_accessor :id, :user_id, :question_id


  def self.followers_for_question_id(question_id)
    user_data = QuestionsDatabase.instance.execute(<<-SQL, question_id)
      SELECT
        users.id, users.fname, users.lname
      FROM
        users
      INNER JOIN
        question_follows ON users.id = question_follows.user_id
      WHERE
        question_follows.question_id = ?
    SQL
    
    user_data.map {|datum| User.new(datum)}
  end

  def self.followed_questions_for_user_id(user_id)
    question_data = QuestionsDatabase.instance.execute(<<-SQL, user_id)
      SELECT
        questions.*
      FROM
        questions
      INNER JOIN
        question_follows ON questions.id = question_follows.question_id
      WHERE
        question_follows.user_id = ?
    SQL
    question_data.map {|datum| Question.new(datum)}
  end

  def self.most_followed_questions(n)
    questions = QuestionsDatabase.instance.execute(<<-SQL, n)
      SELECT
        questions.*
      FROM
        question_follows
      INNER JOIN
        questions ON question_follows.question_id = questions.id
      GROUP BY
        questions.id
      ORDER BY
        COUNT(questions.id) DESC
      LIMIT
        ?
    SQL
    questions.map { |question_info| Question.new(question_info) }
  end

  def self.table_name
    "question_follows"
  end

  def initialize(options)
    @id = options['id']
    @user_id = options['user_id']
    @question_id = options['question_id']
  end
end

class Reply < SuperQ
  attr_accessor :id, :question_id, :parent_id, :user_id, :body

  def self.find_by_user_id(user_id)
    found_data = QuestionsDatabase.instance.execute(<<-SQL, user_id)
      SELECT
        *
      FROM
        replies
      WHERE
        replies.user_id = ?
    SQL
    found_data.map { |datum| Reply.new(datum) }
  end
  
  def self.find_by_question_id(question_id)
    found_data = QuestionsDatabase.instance.execute(<<-SQL, question_id)
      SELECT
        *
      FROM
        replies
      WHERE
        replies.question_id = ?
    SQL
    found_data.map { |datum| Reply.new(datum) }
  end

  def self.table_name
    "replies"
  end

  def initialize(options)
    @id = options['id']
    @question_id = options['question_id']
    @user_id = options['user_id']
    @parent_id = options['parent_id']
    @body = options['body']    
  end

  def author
    User.find_by_id(self.user_id)
  end

  def question
    Question.find_by_id(self.question_id)
  end

  def parent_reply
    self.parent_id.nil? ? nil : Reply.find_by_id(self.parent_id)
  end

  def child_replies
    found_data = QuestionsDatabase.instance.execute(<<-SQL, self.id)
      SELECT
        *
      FROM
        replies
      WHERE
        parent_id = ?
    SQL
    found_data.map { |datum| Reply.new(datum) }
  end

end


class QuestionLike < SuperQ
  attr_accessor :id, :user_id, :question_id

  def self.likers_for_question_id(question_id)
    data = QuestionsDatabase.instance.execute(<<-SQL, question_id)
      SELECT
        users.*
      FROM
        users
      INNER JOIN
        question_likes ON question_likes.user_id = users.id
      WHERE
        question_likes.question_id = ?
    SQL
    data.map { |datum| User.new(datum) }
  end

  def self.num_likes_for_question_id(question_id)
    num = QuestionsDatabase.instance.execute(<<-SQL, question_id)
      SELECT
        COUNT(*) AS count
      FROM
        questions
      INNER JOIN
        question_likes ON questions.id = question_likes.question_id
      WHERE
        questions.id = ?
    SQL
    num.first["count"]
  end

  def self.liked_questions_for_user_id(user_id)
    data = QuestionsDatabase.instance.execute(<<-SQL, user_id)
      SELECT
        questions.*
      FROM
        questions
      INNER JOIN
        question_likes ON questions.id = question_likes.question_id
      WHERE
        question_likes.user_id = ?
    SQL
    data.map { |datum| Question.new(datum) }
  end

  def self.most_liked_questions(n)
    questions = QuestionsDatabase.instance.execute(<<-SQL, n)
      SELECT
        questions.*
      FROM
        question_likes
      INNER JOIN
        questions ON question_likes.question_id = questions.id
      GROUP BY
        questions.id
      ORDER BY
        COUNT(questions.id) DESC
      LIMIT
        ?
    SQL
    questions.map { |question_info| Question.new(question_info) }
  end

  def self.table_name
    "question_likes"
  end

  def initialize(options)
    @id = options['id']
    @user_id = options['user_id']
    @question_id = options['question_id']
  end

end