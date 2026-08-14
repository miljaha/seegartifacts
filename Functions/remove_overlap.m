function [artefacts_removed, seizures_removed, both_removed] = remove_overlap(event_original, artefact_samples, seizure_samples, both_samples, measure)
artefacts_removed = exclude_samples(event_original, artefact_samples, 0, 0);
seizures_removed = exclude_samples(event_original, seizure_samples , 0, 0);
both_removed = exclude_samples(event_original, both_samples, 0, 0);
fprintf('The number of %s that were detected successfully\n', measure);
fprintf("Original: %d\n", size(event_original,1));
fprintf("Artefact-free: %d\n", size(artefacts_removed,1));
fprintf("Seizure-free: %d\n", size(seizures_removed,1));
fprintf("Artefact-seizure-free: %d\n", size(both_removed,1));
end

