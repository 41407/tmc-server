require 'spec_helper'

describe TestRunnerIntegrationSetup, :integration => true do
  include GitTestActions

  describe "running tests on a new submission" do
    before :each do
      @setup = SubmissionTestSetup.new(:exercise_name => 'SimpleExercise')
      @course = @setup.course
      @repo = @setup.repo
      @exercise_project = @setup.exercise_project
      @exercise = @setup.exercise
      @user = @setup.user
      @submission = @setup.submission
    end
    
    it "should create test results for the submission" do
      @exercise_project.solve_add
      @setup.make_zip
      TestRunnerIntegrationSetup.run_submission_tests(@submission)
      
      @submission.test_case_runs.should_not be_empty
      tcr = @submission.test_case_runs.to_a.find {|tcr| tcr.test_case_name == 'SimpleTest testAdd' }
      tcr.should_not be_nil
      tcr.should be_successful
      
      tcr = @submission.test_case_runs.to_a.find {|tcr| tcr.test_case_name == 'SimpleTest testSubtract' }
      tcr.should_not be_nil
      tcr.should_not be_successful
    end
    
    it "should not create multiple test results for the same test method even if it is involved in multiple points"
    
    it "should raise an error if compilation of a test fails" do
      @exercise_project.introduce_compilation_error
      @setup.make_zip
      expect { TestRunnerIntegrationSetup.run_submission_tests(@submission) }.to raise_error(/Compilation error/)
    end
    
    it "should award points for successful exercises" do
      @exercise_project.solve_sub
      @setup.make_zip
      TestRunnerIntegrationSetup.run_submission_tests(@submission)
      
      points = AwardedPoint.where(:course_id => @course.id, :user_id => @user.id).map(&:name)
      points.should include('justsub')
      points.should_not include('addsub')
      points.should_not include('mul')
      points.should_not include('simpletest-all')
    end
    
    it "should not award a point if all tests (potentially in multiple files) required for it don't pass" do
      @exercise_project.solve_addsub
      @setup.make_zip
      TestRunnerIntegrationSetup.run_submission_tests(@submission)
      
      points = AwardedPoint.where(:course_id => @course.id, :user_id => @user.id).map(&:name)
      points.should include('simpletest-all')
      points.should_not include('both-test-files')
    end
    
    it "should award a point if all tests (potentially in multiple files) required for it pass" do
      @exercise_project.solve_all
      @setup.make_zip
      TestRunnerIntegrationSetup.run_submission_tests(@submission)
      
      points = AwardedPoint.where(:course_id => @course.id, :user_id => @user.id).map(&:name)
      points.should include('simpletest-all')
      points.should include('both-test-files')
    end
    
    it "should only ever award more points, never delete old points" do
      @exercise_project.solve_sub
      @setup.make_zip
      TestRunnerIntegrationSetup.run_submission_tests(@submission)
      
      @exercise_project.solve_add
      @setup.make_zip
      TestRunnerIntegrationSetup.run_submission_tests(@submission)
      
      points = AwardedPoint.where(:course_id => @course.id, :user_id => @user.id).map(&:name)
      points.should include('justsub')
      points.should include('addsub')
      points.should include('simpletest-all')
      points.should_not include('mul') # in SimpleHiddenTest
    end
    
    it "should enforce access restrictions on the student's code" do
      @exercise_project.solve_all
      @exercise_project.write_empty_method_body('new java.io.FileOutputStream("../omg.hax");')
      @setup.make_zip
      
      TestRunnerIntegrationSetup.run_submission_tests(@submission)
      
      tcr = @submission.test_case_runs.to_a.find {|tcr| tcr.test_case_name == 'SimpleTest testEmptyMethod' }
      tcr.should_not be_nil
      tcr.should_not be_successful
      tcr.message.should include('AccessControlException')
      tcr.message.should include('FilePermission ../omg.hax write')
    end
  end
end