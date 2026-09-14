require "../spec_helper"
require "../data/example_models"

module CustomSchemaSpec
  class Author
    include Lustra::Model

    self.schema = "association_schema"
    self.table = "schema_authors"

    primary_key
    column name : String

    has_many articles : CustomSchemaSpec::Article, foreign_key: "author_id"
    has_one article : CustomSchemaSpec::Article?, foreign_key: "author_id"
    has_many categories : CustomSchemaSpec::Category, through: CustomSchemaSpec::Article, own_key: "author_id", foreign_key: "category_id"
  end

  class Article
    include Lustra::Model

    self.schema = "association_schema"
    self.table = "schema_articles"

    primary_key
    column title : String

    belongs_to author : CustomSchemaSpec::Author, foreign_key: "author_id"
    belongs_to category : CustomSchemaSpec::Category, foreign_key: "category_id"
  end

  class Category
    include Lustra::Model

    self.schema = "association_schema"
    self.table = "schema_categories"

    primary_key
    column name : String
  end

  def self.with_association_tables(&)
    temporary do
      Lustra::SQL.execute <<-SQL
        SET LOCAL search_path TO public;
        CREATE SCHEMA association_schema;
        CREATE TABLE association_schema.schema_authors (id bigint PRIMARY KEY, name text NOT NULL);
        CREATE TABLE association_schema.schema_articles (id bigint PRIMARY KEY, title text NOT NULL, author_id bigint NOT NULL, category_id bigint NOT NULL);
        CREATE TABLE association_schema.schema_categories (id bigint PRIMARY KEY, name text NOT NULL);
        CREATE TABLE public.schema_authors (LIKE association_schema.schema_authors INCLUDING ALL);
        CREATE TABLE public.schema_articles (LIKE association_schema.schema_articles INCLUDING ALL);
        CREATE TABLE public.schema_categories (LIKE association_schema.schema_categories INCLUDING ALL);
        INSERT INTO association_schema.schema_authors VALUES (1, 'With articles'), (2, 'Without articles');
        INSERT INTO association_schema.schema_articles VALUES (1, 'First', 1, 1), (2, 'Second', 1, 1);
        INSERT INTO association_schema.schema_categories VALUES (1, 'Schema category');
        INSERT INTO public.schema_authors VALUES (2, 'Public author');
        INSERT INTO public.schema_articles VALUES (3, 'Public article', 2, 2);
        INSERT INTO public.schema_categories VALUES (2, 'Public category');
        SQL

      yield
    end
  end

  describe "Associations inside another schema" do
    it "joins the has_many target in its configured schema" do
      CustomSchemaSpec.with_association_tables do
        Author.query.join(:articles).to_a.map(&.id).should eq([1_i64, 1_i64])
      end
    end

    it "finds associated records using the configured schema" do
      CustomSchemaSpec.with_association_tables do
        Author.query.where.associated(:articles).to_a.map(&.id).should eq([1_i64, 1_i64])
      end
    end

    it "finds missing associations using the configured schema" do
      CustomSchemaSpec.with_association_tables do
        Author.query.where.missing(:articles).to_a.map(&.id).should eq([2_i64])
      end
    end

    it "counts has_many records in the configured schema" do
      CustomSchemaSpec.with_association_tables do
        author = Author.query.where(id: 1).with_count(:articles).first!(fetch_columns: true)
        author.attributes["articles_count"].should eq(2_i64)
      end
    end

    it "joins the belongs_to target in its configured schema" do
      CustomSchemaSpec.with_association_tables do
        Article.query.join(:author).to_a.map(&.id).sort!.should eq([1_i64, 2_i64])
      end
    end

    it "counts belongs_to records in the configured schema" do
      CustomSchemaSpec.with_association_tables do
        article = Article.query.where(id: 1).with_count(:author).first!(fetch_columns: true)
        article.attributes["author_count"].should eq(1_i64)
      end
    end

    it "uses the configured schema for nilable has_one joins and counts" do
      CustomSchemaSpec.with_association_tables do
        Author.query.where.associated(:article).to_a.map(&.id).should eq([1_i64, 1_i64])
        author = Author.query.where(id: 1).with_count(:article).first!(fetch_columns: true)
        author.attributes["article_count"].should eq(2_i64)
      end
    end

    it "uses the configured schema for both tables in through joins" do
      CustomSchemaSpec.with_association_tables do
        Author.query.join(:categories).to_a.map(&.id).should eq([1_i64, 1_i64])
        Author.query.where.missing(:categories).to_a.map(&.id).should eq([2_i64])
      end
    end

    it "counts through rows in the configured schema" do
      CustomSchemaSpec.with_association_tables do
        author = Author.query.where(id: 1).with_count(:categories).first!(fetch_columns: true)
        author.attributes["categories_count"].should eq(2_i64)
      end
    end

    it "uses the configured schema when selecting the through table directly" do
      CustomSchemaSpec.with_association_tables do
        Author.query.join(:schema_articles).to_a.map(&.id).should eq([1_i64, 1_i64])
        author = Author.query.where(id: 1).with_count(:schema_articles).first!(fetch_columns: true)
        author.attributes["schema_articles_count"].should eq(2_i64)
      end
    end
  end

  describe "Model inside another schema" do
    it "create a model" do
      temporary do
        reinit_example_models

        model = ModelWithinAnotherSchema.create! title: "Some title" # Ensure create works

        model.class.full_table_name.should eq(
          %("another_schema"."model_within_another_schemas")
        )
        model.persisted?.should be_true

        mdl = ModelWithinAnotherSchema.query.where { title == "Some title" }.first!

        mdl.title = "A new title"
        mdl.save! # Ensure update works
        ModelWithinAnotherSchema.query.first!.title.should eq("A new title")

        ModelWithinAnotherSchema.query.delete_all # Ensure delete works
        ModelWithinAnotherSchema.query.count.should eq(0)

        model = ModelWithinAnotherSchema.create! title: "Some title" # Ensure create works
        model.delete                                                 # Ensure delete one works

        ModelWithinAnotherSchema.create! title: "Some title" # Ensure create works
        Lustra::SQL.truncate(ModelWithinAnotherSchema)       # ensure truncate works
      end
    end
  end
end
