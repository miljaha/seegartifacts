%% Initialization
clear; close all; clc;
addpath(genpath('Main Functions'));
addpath(genpath('Auxiliary Functions'));

%% Input Parameters
subj_number           = 23;          % subject number
user_datetime_range   = {"13-Aug-2020 22:22:00","14-Aug-2020 7:31:00"};     % if any entry is empty earliest/latest available datetime will be selected
data_files            = {""};        % if empty it evokes automatic data file selection
user_segment_duration = 5*60;        % slice data into 5-minute segments to reduce computations
user_measure          = ["FR","R","S","SFR","SR"]; % (dont worry about upper/lower cases or the order, the system takes care of that)

%% Function calling
data_dir = "C:\Akseli\Pat" + string(subj_number) + "\Koko_yo";
z = automatic_detection_spontaneous(subj_number, data_dir, data_files, ...
    user_datetime_range, user_segment_duration, user_measure);
