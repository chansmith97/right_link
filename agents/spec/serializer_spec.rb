require File.join(File.dirname(__FILE__), '..', '..', 'spec', 'spec_helper')

describe RightScale::Serializer do

  describe "Format" do

    it "supports JSON format" do
      [ :json, "json" ].each do |format|
        serializer = RightScale::Serializer.new(format)
        serializer.instance_eval { @serializers.first }.should == JSON
      end
    end

    it "supports Marshal format" do
      [ :marshal, "marshal" ].each do |format|
        serializer = RightScale::Serializer.new(format)
        serializer.instance_eval { @serializers.first }.should == Marshal
      end
    end

    it "supports YAML format" do
      [ :yaml, "yaml" ].each do |format|
        serializer = RightScale::Serializer.new(format)
        serializer.instance_eval { @serializers.first }.should == YAML
      end
    end

    it "should default to Marshal format if not specified" do
      serializer = RightScale::Serializer.new
      serializer.instance_eval { @serializers.first }.should == Marshal
      serializer = RightScale::Serializer.new(nil)
      serializer.instance_eval { @serializers.first }.should == Marshal
    end

  end # Format

  describe "Serialization of Packet" do

    it "should cascade through available serializers" do
      serializer = RightScale::Serializer.new
      flexmock(serializer).should_receive(:cascade_serializers).with(:dump, "hello")
      serializer.dump("hello")
    end

    it "should try all three supported formats (JSON, Marshal, YAML)" do
      flexmock(JSON).should_receive(:dump).with("hello").and_raise(StandardError)
      flexmock(Marshal).should_receive(:dump).with("hello").and_raise(StandardError)
      flexmock(YAML).should_receive(:dump).with("hello").and_raise(StandardError)

      lambda { RightScale::Serializer.new.dump("hello") }.should raise_error(RightScale::Serializer::SerializationError)
    end

    it "should raise SerializationError if packet could not be serialized" do
      flexmock(JSON).should_receive(:dump).with("hello").and_raise(StandardError)
      flexmock(Marshal).should_receive(:dump).with("hello").and_raise(StandardError)
      flexmock(YAML).should_receive(:dump).with("hello").and_raise(StandardError)

      serializer = RightScale::Serializer.new
      lambda { serializer.dump("hello") }.should raise_error(RightScale::Serializer::SerializationError)
    end

    it "should return serialized packet" do
      serialized_packet = flexmock("Packet")
      flexmock(Marshal).should_receive(:dump).with("hello").and_return(serialized_packet)

      serializer = RightScale::Serializer.new(:marshal)
      serializer.dump("hello").should == serialized_packet
    end

  end # Serialization of Packet

  describe "De-Serialization of Packet" do

    it "should cascade through available serializers" do
      serializer = RightScale::Serializer.new
      flexmock(serializer).should_receive(:cascade_serializers).with(:load, "olleh")
      serializer.load("olleh")
    end

    it "should try all three supported formats (JSON, Marshal, YAML)" do
      flexmock(JSON).should_receive(:load).with("olleh").and_raise(StandardError)
      flexmock(Marshal).should_receive(:load).with("olleh").and_raise(StandardError)
      flexmock(YAML).should_receive(:load).with("olleh").and_raise(StandardError)

      lambda { RightScale::Serializer.new.load("olleh") }.should raise_error(RightScale::Serializer::SerializationError)
    end

    it "should raise SerializationError if packet could not be de-serialized" do
      flexmock(JSON).should_receive(:load).with("olleh").and_raise(StandardError)
      flexmock(Marshal).should_receive(:load).with("olleh").and_raise(StandardError)
      flexmock(YAML).should_receive(:load).with("olleh").and_raise(StandardError)

      serializer = RightScale::Serializer.new
      lambda { serializer.load("olleh") }.should raise_error(RightScale::Serializer::SerializationError)
    end

    it "should return de-serialized packet" do
      deserialized_packet = flexmock("Packet")
      flexmock(Marshal).should_receive(:load).with("olleh").and_return(deserialized_packet)

      serializer = RightScale::Serializer.new(:marshal)
      serializer.load("olleh").should == deserialized_packet
    end

  end # De-Serialization of Packet

end # RightScale::Serializer
