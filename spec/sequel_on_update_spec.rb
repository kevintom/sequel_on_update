require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

class Item < Sequel::Model; end

describe "SequelOnUpdate" do

  describe "base case" do
    it "should be loaded using Model.plugin" do
      Item.plugin :on_update, :fields => [:name], :hook => :test
      Item.plugins.should include(Sequel::Plugins::OnUpdate)
    end

    it "should require a field array" do
      class Item2 < Sequel::Model; end
      lambda {Item2.plugin :on_update}.should raise_error(ArgumentError, ":fields must be a non-empty array")      
    end

    it "should require a hook to be a symbol or callable" do
      class Item2 < Sequel::Model; end
      lambda { Item2.plugin :on_update, :fields => [:name], :hook => 'xy' }.should raise_error(ArgumentError, ":hook must be Symbol or callable")
    end
  end

  describe "hook handling" do
    it "should support multiple fields for the same hook" do
      class Item4 < Sequel::Model
        plugin :on_update, :fields => [:username, :password], :hook => :send_email
      end
      Item4.on_update_options[:fields].should include(:username)
      Item4.on_update_options[:fields].should include(:password)
      Item4.on_update_options[:hooks][:username].should eql :send_email
      Item4.on_update_options[:hooks][:password].should eql :send_email
    end
    it "should support a mapping of fields to hooks" do
      class Item5 < Sequel::Model
        plugin :on_update, :fields => [:username], :hook => :send_email
        plugin :on_update, :fields => [:password], :hook => :test_email
      end
      Item5.on_update_options[:fields].should include(:username)
      Item5.on_update_options[:fields].should include(:password)
      Item5.on_update_options[:hooks][:username].should eql :send_email
      Item5.on_update_options[:hooks][:password].should eql :test_email
    end
  end

  describe "field handling" do
    it 'should remove nil field names' do
      class Item2 < Sequel::Model; end
      Item2.plugin :on_update, :fields => [:name, nil], :hook => :test
      Item2.on_update_options[:fields].should eql [:name]
    end

    it 'should remove duplicate fields' do
      class Item2 < Sequel::Model; end
      Item2.plugin :on_update, :fields => [:name, :slug, :name], :hook => :test
      Item2.on_update_options[:fields].count.should eql 2
    end

    it 'should add to the field list on multiple calls' do
      #not overwrite fields when you add more fields with different options
      class Item2 < Sequel::Model; end
      Item2.plugin :on_update, :fields => [:name], :hook => :test
      Item2.plugin :on_update, :fields => [:slug], :hook => :test
      Item2.plugin :on_update, :fields => [:more, :columns, :name], :hook => :test
      Item2.on_update_options[:fields].should eql [:name, :slug, :more, :columns]
    end
  end

  describe "#collect_hooks" do
    it "should only return one hook when it's the same for all fields" do
      class Item < Sequel::Model
        plugin :on_update, :fields => [:name, :slug, :password], :hook => :test
      end
      i = Item.create(:name => "roxio", :slug => "burner", :password => "foo")
      i.name = "burner"
      i.slug = "burn"
      i.password = "bar"
      i.before_update
      i.collect_hooks.should eql [:test]
    end
    it "should return all hooks for modified fields" do
      class Item < Sequel::Model
        plugin :on_update, :fields => [:name, :slug], :hook => :test
        plugin :on_update, :fields => [:password], :hook => :blerg
      end
      i = Item.create(:name => "roxio", :slug => "burner", :password => "foo")
      i.name = "burner"
      i.slug = "burn"
      i.password = "bar"
      i.before_update
      i.collect_hooks.should eql [:test, :blerg]
    end
    it "should return all hooks with at least 1 modified field" do
      class Item < Sequel::Model
        plugin :on_update, :fields => [:name, :slug], :hook => :test
        plugin :on_update, :fields => [:password], :hook => :blerg
      end
      i = Item.create(:name => "roxio", :slug => "burner", :password => "foo")
      i.slug = "burn"
      i.password = "bar"
      i.before_update
      i.collect_hooks.should eql [:test, :blerg]
    end
    it "should return only hooks for modified fields" do
      class Item < Sequel::Model
        plugin :on_update, :fields => [:name], :hook => :test
        plugin :on_update, :fields => [:slug], :hook => :oven
        plugin :on_update, :fields => [:password], :hook => :blerg
      end
      i = Item.create(:name => "roxio", :slug => "burner", :password => "foo")
      i.name = "burner"
      i.password = "bar"
      i.before_update
      i.collect_hooks.should eql [:test, :blerg]
    end
    it "should return a hook only once" do
      class Item < Sequel::Model
        plugin :on_update, :fields => [:name], :hook => :test
        plugin :on_update, :fields => [:slug], :hook => :test
        plugin :on_update, :fields => [:password], :hook => :test
      end
      i = Item.create(:name => "roxio", :slug => "burner", :password => "foo")
      i.name = "burner"
      i.slug = "burn"
      i.password = "bar"
      i.before_update
      i.collect_hooks.should eql [:test]
    end
  end
  
  describe "#after_update" do
    it "should pass in the list of fields changed when calling the hook" do
      class Item < Sequel::Model
        plugin :on_update, :fields => [:name, :slug, :password], :hook => :test
      end
      i = Item.create(:name => "roxio", :slug => "burner", :password => "foo")
      i.name = "burner"
      i.slug = "burn"
      i.password = "bar"
      i.should_receive(:test).with([:name, :slug, :password]).and_return(true)
      i.save
    end
  end
  
  describe "#changed_columns" do
    it "should list the columns with changed values" do
      i = Item.create(:name => "whatever")
      i.name = "colio"
      i.changed_columns.should include(:name)
    end
  end
end
