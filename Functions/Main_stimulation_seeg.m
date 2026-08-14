%% Initialization
clear; close all; clc;
addpath(genpath('Main Functions'));
addpath(genpath('Auxiliary Functions'));

%% Input Parameters
subj_number         = 22;        % subject number
user_datetime_range = {"2-3-2020 10:20:00","3/March/2020 10:30:0"};   % if any entry is empty earliest/latest available datetime will be selected
data_files          = {""};      % if empty it evokes automatic data file selection
user_frequency      = "1";       % if empty 1Hz is the default (dont worry about adding/removing the unit, the system takes care of that)
user_current        = "5mA";     % if empty 5mA is the default (dont worry about adding/removing the unit, the system takes care of that)
user_measure        = ["FR","R","S","GS","SFR","SR"]; % (dont worry about upper/lower cases or the order, the system takes care of that)

%% Function calling
data_dir = "C:\Datasets\Data\Pat" + string(subj_number) + "\Stimulation_Files";
z = automatic_detection_stimulation(subj_number, data_dir, data_files, ...
    user_datetime_range, user_frequency, user_current, user_measure);
